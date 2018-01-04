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

package require dav::carddav
package require getpass

# This class provides an implementation of a data provider backed by a CardDAV
# server.
#
::http::register https 443 ::tls::socket

oo::class create provider::carddav {

    variable mydav

    ##
    # Construct a CardDAV based provider.
    # Configuration MUST include
    # - user The username to access the CardDAV resource
    # - url The URL to the CardDAV server or resource. The string %%USER%% is
    #       substituted with the value of the "user" config entry (see above)
    # Configuration MIGHT include
    # - pass The password to access the CardDAV resource. If it's not set,
    #        the user is prompted to provide one.
    constructor {config} {
        set user [dict get $config user]
        set url [string map [list %%USER%% $user] [dict get $config url]]
        set mydav [CardDAV new $url]
        if {[dict exists $config pass]} {
            set pass [dict get $config pass]
        } else {
            set pass [getpass::getpass $user]
        }
        $mydav setUser $user
        $mydav setPass $pass
        $mydav setVerbose [expr {![catch {dict get $config verbose}]}]
    }

    ##
    # Cleanup.
    destructor {
        $mydav destroy
    }

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
    # Query CardDAV.
    method Query {{person {}}} {
        join [lmap abook [$mydav getAddressBooks] {
            $mydav fillAddressBook $abook {FN BDAY} $person
            lmap vcard [$abook searchVCards FN $person] {
                set fn [$vcard getFirstValue FN]
                set bd [$vcard getFirstValue BDAY]
                # VCard stores non-specified years as a dash. We need to turn
                # them into 0000.
                regsub {^-} $bd 0000 bd
                expr {$bd eq {} ? [continue]
                                : [dict create person $fn birthday $bd]}
            }
        }]
    }
}

