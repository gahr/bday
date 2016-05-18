# vim: ft=tcl ts=4 sw=4 expandtab tw=79 colorcolumn=80

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
# This module provides date-related functionalities.

package require Tcl 8.6
package provide datelib 0.1.0

namespace eval datelib {
    variable nonLeapModuli {100 200 300}
    variable dateRegexp    {^(?:(\d{4})-)?(\d{1,2})-(\d{1,2})$}

    proc isLeapYear {y} {
        variable nonLeapModuli
        scan $y %d y
        
        return [expr {($y % 4) == 0 && ($y % 400) ni $nonLeapModuli}]
    }

    ##
    # Parse a date in yyyy-mm-dd or mm-dd format and check for validity. Return
    # the {yyyy mm dd} list if date is valid, the empty string otherwise.
    proc parseDate {date} {
        variable dateRegexp

        if {![regexp $dateRegexp $date _ y m d]} {
            return {}
        }

        set y [format %04s $y]
        set m [format %02s $m]
        set d [format %02s $d]

        set isValid [expr {
            ($d >= {01} && $m >= {01} && $m <= {12})
            &&
            (
                ($m in {{01} {03} {05} {07} {08} {10} {12}} && $d <= {31}) ||
                ($m in {{04} {06} {09} {11}} && $d <= {30}) ||
                ($m == {02} && $d <= {28} + [isLeapYear $y])
            )
        }]

        if {$isValid} {
            return [list $y $m $d]
        } else {
            return {}
        }
    }

    ##
    # Return today's date as the (yyyy mm dd) list.
    proc today {} {
        split [clock format [clock seconds] -format %Y-%m-%d] -
    }

    ##
    # Return the seconds since the epoch of the next occurrence of date. Date
    # might be in yyyy-mm-dd or mm-dd format. In the first case, the yyyy part
    # is ignored.
    proc next {date} {
        variable this_year
        variable this_year
        variable next_year

        lassign [today] ty tm td
        lassign [parseDate $date] _ m d
        if {$m < $tm || ($m == $tm && $d < $td)} {
            incr ty 
        }
        clock scan $ty-$m-$d -format %Y-%m-%d
    }

    ##
    # Handy wrapper around [clock seconds]
    proc now {} {
        clock seconds
    }

    ##
    # Handy wrapper around [clock format]. If val is empty, the current time is
    # used.
    proc cfmt {fmt {val {}}} {
        if {$val eq {}} {
            set val [clock seconds]
        }
        clock format $val -format $fmt
    }

    ##
    # Handy wrapper around [clock scan]
    proc cscn {fmt val} {
        clock scan $val -format $fmt
    }

    ##
    # Handy wrappper around [clock add]. If val is empty, the current time is
    # used.
    proc cadd {count unit {val {}}} {
        if {$val eq {}} {
            set val [clock seconds]
        }
        clock add $val $count $unit
    }
}
