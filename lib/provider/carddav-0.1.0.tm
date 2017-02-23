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

    variable myurl
    variable myuser

    ##
    # Construct a CardDAV based provider.
    # Configuration MUST include
    # - user The username to access the CardDAV resource
    # - url The full URL to the CardDAV resource. The string %%USER%% is
    #       substituted with the value of the "user" config entry (see above)
    constructor {config} {
        variable myurl
        variable myuser

        set myuser [dict get $config user]
        set myurl [string map [list %%USER%% $myuser] [dict get $config url]]
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
        variable myurl
        variable myuser
        set mypass [my GetPass]

        my Query $myurl $myuser $mypass $person
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
        variable myurl
        variable myuser
        set mypass [my GetPass]

        my Query $myurl $myuser $mypass
    }

    ##
    # No-op. This is read only, so saving is not needed.
    method save {} { }

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
    # Query CardDAV.
    method Query {url user pass {person {}}} {

        set headers [list Authorization \
                          "Basic [base64::encode ${user}:${pass}]" \
                          Depth 1 Content-type {application/xml; charset=utf-8}]

        set query {
            <C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
                <D:prop>
                    <C:address-data content-type="text/vcard" version="4.0">
                        <C:prop name="FN"/>
                        <C:prop name="BDAY"/>
                    </C:address-data>
                </D:prop>
            </C:addressbook-query>
        }

        set d [list]

        # Make the request
        set tok [::http::geturl $url \
            -method REPORT \
            -headers $headers \
            -query $query \
            -keepalive true]
        set xml [::http::data $tok]
        set ncode [::http::ncode $tok]
        set code [::http::code $tok]
        ::http::cleanup $tok
        if {$ncode >= 400} {
            return -code error "Error: $code"
        }

        # Parse the response
        dom parse $xml doc
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

