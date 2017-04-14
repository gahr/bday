# vim: ft=tcl ts=4 sw=4 expandtab tw=79 colorcolumn=80

##
#  Copyright (C) 2017 Pietro Cerutti <gahr@gahr.ch>
#  
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#  
#  THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#  SUCH DAMAGE.

package require Tcl 8.6
package require base64
package require http 2
package require tls
package require tdom

# This class provides an implementation of a data provider backed by a CardDAV
# server.
#
::http::register https 443 ::tls::socket

oo::class create provider::carddav {

    variable myhost
    variable mypath
    variable myuser
    variable mypass
    variable myhead
    variable myverbose

    ##
    # Construct a CardDAV based provider.
    # Configuration MUST include
    # - user The username to access the CardDAV resource
    # - url The URL to the CardDAV server or resource. The string %%USER%% is
    #       substituted with the value of the "user" config entry (see above)
    constructor {config} {
        variable myhost
        variable mypath
        variable myuser
        variable mypass
        variable myhead
        variable myverbose 

        set myuser [dict get $config user]
        set mypass [my GetPass]
        set url [string map [list %%USER%% $myuser] [dict get $config url]]
        lassign [my ParseSimpleRef $url] myhost mypath
        if {$myhost eq {}} {
            return -code error "Invalid URL in config: $url"
        }
        set myhead [list \
            Authorization "Basic [base64::encode ${myuser}:${mypass}]" \
            Depth 1 Content-Type {application/xml; charset=utf-8}]

        set myverbose [expr {![catch {dict get $config verbose}]}]
    }

    ##
    # Cleanup.
    destructor { }

    ##
    # Set or modify a person's birthday.
    method setBirthday {person birthday} {
        return -code error "Unsupported: CardDAV is read-only (for now)"
    }

    ##
    # Return a person's birthday, or the empty string if person wasn't found.
    method getBirthday {person} {
        my Query $person
    }

    ##
    # Remove a person's birthday.
    method remove {person} {
        return -code error "Unsupported: CardDAV is read-only (for now)"
    }

    ##
    # Return all birthdays in the CardDAV database. Only the basic "person"
    # and "birthday" attributes are supported by this implementation.
    method get {} {
        my Query
    }

    ##
    # No-op. This is read only, so saving is not needed.
    method save {} { }

    ##
    # Log a message to stderr, if verbose true appears in the config
    method Log {msg} {
        variable myverbose
        set fmt {%H:%M:%S}
        if {$myverbose} {
            set t [clock milliseconds]
            set s  [expr {$t / 1000}]
            set ms [format %03d [expr {$t % 1000}]]
            puts stderr "[clock format $s -format $fmt].$ms $msg"
        }
    }

    ## 
    # Query for a password.
    method GetPass {} {
        variable myuser

        set stty_save [exec stty -g]
        exec stty -echo
        puts -nonewline stderr "Password for $myuser: "
        flush stderr
        gets stdin pass
        exec stty $stty_save
        puts stderr {}
        return $pass
    }

    ##
    # This matches any content line and returns
    # . group
    # . parameters
    # . value
    #
    method VCardLineRegexp {name} {
        return "^(.*\.)?${name}(;.*)*:(.*)$"
    }

    ##
    # Parse a Simple-ref, as defined in RFC4918, §8.3. WebDAV only recognizes
    # two form or URLs, absolute URIs and absolute paths. This method extracts
    # the host (formally Scheme + Authority) and the path (formally Path +
    # Query + Fragment) parts of a URI, where the host part could be missing.
    # The path is always returned with a leading slash, even if empty in the
    # original URI.
    # https://tools.ietf.org/html/rfc4918#section-8.3
    method ParseSimpleRef {uri} {
        if {![regexp {([^:]+://[^/]+)?(/.*)?} $uri _ host path]} {
            return -code error "Invalid URI: $uri"
        }
        if {$path eq {}} {
            set path /
        }
        return [list $host $path]
    }

    ##
    # Make an HTTP request
    method MakeHttpReq {path {method GET} {query {}}} {
        variable myhead
        variable myhost

        set tok [::http::geturl ${myhost}${path} -method $method \
                                -headers $myhead \
                                -query $query -keepalive 1]
        list [::http::ncode $tok] [::http::code $tok] \
             [::http::meta  $tok] [::http::data $tok]
    }

    ##
    # Find the CardDAV entry point
    method FindCardDAVEntryPoint {} {
        variable myhost
        variable mypath
        variable myhead

        # If a path was not given, use the .well-known method, otherwise assume
        # it's the correct one
        if {$mypath ne {/}} {
            return
        }

        lassign [my MakeHttpReq "/.well-known/carddav"] ncode _ head
        if {$ncode == 302} {
            if {[catch {dict get $head Location} location]} {
                return -code error \
                    "Response 302 missing Location header"
            }
            lassign [my ParseSimpleRef $location] myhost mypath
            if {$myhost eq {}} {
                return -code error \
                    "Response 302's Location header missing absolute URI:\
                    $location"
            }
            my Log "FindCardDAVEntryPoint - found $mypath"
        }
    }

    ## 
    # Find an addressbook resource within the collection starting at an
    # absolute path. The return value is also either an absolute path or the
    # empty string if no address book was found.
    method FindAddressBook {path {recursing 0}} {
        variable myhost
        variable myhead

        set query {
            <propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>
        }
        lassign [my MakeHttpReq $path PROPFIND $query] ncode code head body
        if {$ncode != 207} {
            return -code error $code
        }

        dom parse $body doc
        $doc documentElement root
        set ns {d DAV: card urn:ietf:params:xml:ns:carddav}
        set base {/d:multistatus/d:response/d:propstat/d:prop/d:resourcetype/}
        set href {/../../../../d:href}

        set abook_uri {}

        # Try to find an addressbook
        foreach href [lreverse [$root selectNodes -namespaces $ns "${base}card:addressbook${href}"]] {
            set abook_uri [lindex [my ParseSimpleRef [$href text]] 1]
            break
        }

        # Try to find inner collections
        if {$abook_uri eq {}} {
            foreach href [lreverse [$root selectNodes -namespaces $ns "${base}d:collection${href}"]] {
                set coll_path [lindex [my ParseSimpleRef [$href text]] 1]
                if {$coll_path eq $path} {
                    # Skip self
                    continue
                }

                set abook_uri [my FindAddressBook $coll_path 1]
                if {$abook_uri ne {}} {
                    break
                }
            }
        }

        my Log "FindAddressBook - $path -> $abook_uri"
        return $abook_uri
    }

    ##
    # Query CardDAV.
    method Query {{person {}}} {
        variable myhost
        variable mypath
        variable myhead

        # Figure out the resource
        my FindCardDAVEntryPoint
        set path [my FindAddressBook $mypath]
        if {$path eq {}} {
            return -code error "No address books found"
        }

        set d [list]

        # Make the request
        set query {
            <C:addressbook-query xmlns:D="DAV:"
                                 xmlns:C="urn:ietf:params:xml:ns:carddav">
                <D:prop>
                    <C:address-data content-type="text/vcard"
                                    version="4.0">
                        <C:prop name="FN"/>
                        <C:prop name="BDAY"/>
                    </C:address-data>
                </D:prop>
            </C:addressbook-query>
        }
        lassign [my MakeHttpReq $path REPORT $query] ncode code head body
        if {$ncode != 207} {
            return -code error $code
        }

        # Parse the response
        dom parse $body doc
        $doc documentElement root
        set vcards [list]
        set ns {d DAV: card urn:ietf:params:xml:ns:carddav}
        foreach node [$root selectNodes -namespaces $ns {/d:multistatus/d:response/d:propstat/d:prop/card:address-data}] {
            lappend vcards [$node text]
        }

        # On each VCard
        foreach vcard $vcards {
            # Fix end of lines
            set vcard [string map {"\r\n" "\n"} $vcard]

            # Split into lines, skip empty ones
            set lines [split $vcard "\n"]
            set lines [lmap l $lines {if {$l eq {}} { continue } { set l }}]

            # Check first and end line
            if {[lindex $lines 0] ne {BEGIN:VCARD} || [lindex $lines end] ne {END:VCARD}} {
                puts "Invalid vcard lines: $lines"
            }

            # Unfold continuation lines
            for {set i 0} {$i < [llength $lines]} {incr i} {
                set line [lindex $lines $i]
                if {[regexp {^[[:space:]]} $line]} {
                    incr i -1
                    lset lines $i "[lindex $lines $i][string trimleft $line]"
                    set lines [lreplace $lines $i+1 $i+1]
                }
            }

            set fn [lsearch -inline -regexp $lines {^(.*\.)?FN}]
            set bd [lsearch -inline -regexp $lines {^(.*\.)?BDAY}]
            if {$fn eq {} || $bd eq {}} {
                continue
            }

            # FN element
            regexp -nocase [my VCardLineRegexp FN] $fn _ fn_group fn_params fn_value

            # BDAY element
            regexp -nocase [my VCardLineRegexp BDAY] $bd _ bd_group bd_params bd_value

            if {$person ne {} && ![regexp -nocase ".*${person}.*" $fn_value]} {
                continue
            }

            # Apple worksaround the lack of mm-dd only BDAYs in vCard 3 by
            # defaulting to year 1604. See
            # https://github.com/nextcloud/3rdparty/blob/ae67e91/sabre/vobject/lib/VCardConverter.php#L107-L119
            if {![string compare -length 5 $bd_value {1604-}]} {
                set bd_value [string replace $bd_value 0 3 0000]
            }

            lappend d [dict create person $fn_value birthday $bd_value]
        }

        set d
    }
}

