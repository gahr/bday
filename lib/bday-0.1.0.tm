#y  vim: ft=tcl ts=4 sw=4 expandtab tw=79 colorcolumn=80

##
#  Copyright (C) 2016 Pietro Cerutti <gahr@gahr.ch>
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
#
# This module provides functionality to retrieve birthday information from a
# data provider. Birthday information can then be queried using a natural
# language interface, modified, and stored back using the same data provider.
#
# See README.md for documentation.
#

package require Tcl 8.6
package require datelib
package require lambda ;# from Tcllib

package provide bday 0.1.0

catch {bday destroy}
oo::class create bday {

    variable pInst ;# Instance of the provider

    ##
    # Construct a bday object that interfaces with a data provider of class
    # "provider" to access the data. The "config" dictionary is data provider
    # dependent and is passed on to the provider as-is.
    constructor {provider config} {
        variable pInst

        package require provider::$provider
        set pInst [provider::$provider new $config]
    }

    destructor {
        variable pInst

        $pInst destroy
    }

    ##
    # Set (or modify) a person's birthday. Date must be either in yyyy-mm-dd or
    # mm-dd format.
    method setBirthday {person birthday} {
        variable pInst

        set l [::datelib::parseDate $birthday]
        if {$l eq {}} {
            return -code error "Invalid date: $birthday"
        }

        $pInst setBirthday $person [join $l -]

        return
    }

    ##
    # Get a person's birthday.
    method getBirthday {person} {
        variable pInst

        return [$pInst getBirthday $person]
    }

    ##
    # Get a list of persons having birthday on a date
    method getPeople {date} {
        variable pInst

        set data [$pInst get]
        puts $data
    }

    ##
    # Return the full contents of the datastore. The return value must be a
    # list of dictionaries having at least the "person" and "birthday" keys.
    method get {} {
        variable pInst

        return [$pInst get]
    }

    ##
    # Return a list of upcoming birthdays, from the earliest to the latest. The
    # format is the same as "get".
    method getUpcoming {} {
        lassign [datelib::today] today_y today_m today_d
        set thisYear [list]
        set nextYear [list]
        set sorted [lsort -command [lambda {a b} {
            set adate [string range [dict get $a birthday] 5 end]
            set bdate [string range [dict get $b birthday] 5 end]
            string compare $adate $bdate
        }] [my get]]
        foreach entry $sorted {
            lassign [split [dict get $entry birthday] -] y m d
            if {$m < $today_m || ($m == $today_m && $d < $today_d)} {
                lappend nextYear $entry
            } else {
                lappend thisYear $entry
            }
        }

        return [concat $thisYear $nextYear]
    }

    method remove {person} {
        variable pInst

        $pInst remove $person
        return
    }

    method save {} {
        variable pInst

        $pInst save
        return
    }
}

