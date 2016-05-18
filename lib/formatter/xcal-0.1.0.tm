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

package require Tcl 8.6
package require tdom

package provide formatter::xcal 0.1.0

# This class provides a formatter to produce output in xCal [RFC6321] format.
oo::class create formatter::xcal {

    method createProp {doc propname proptype propval} {
        set propElem [$doc createElement $propname]
        set propText [$doc createElement $proptype]
        set propVal  [$doc createTextNode $propval]
        $propText appendChild $propVal
        $propElem appendChild $propText
        return $propElem
    }

    ##
    # Print a list of birthdays as xCal VEVENTs.
    method print {l} {

        set now [::datelib::cfmt %Y-%m-%dT%H:%M:%SZ]

        chan configure stdout -encoding utf-8

        dom createDocument icalendar doc
        $doc documentElement root
        $root setAttribute xmlns {urn:ietf:params:xml:ns:icalendar-2.0}
        set vcal [$root appendChild [$doc createElement vcalendar]]

        # Properties
        set prop [$vcal appendChild [$doc createElement properties]]
        $prop appendChild [my createProp $doc version text 2.0]
        $prop appendChild [my createProp $doc prodid text /gahr@gahr.ch/bday]

        # Components
        set comp [$vcal appendChild [$doc createElement components]]

        foreach entry $l {
            set person [dict get $entry person]
            set birthday [dict get $entry birthday]
            lassign [::datelib::parseDate $birthday] y m d
            if {$y == 0} {
                set start [::datelib::cfmt %Y-%m-%d [::datelib::next $birthday]]
            } else {
                set start [string map {- {}} $birthday]
            }

            set vevent [$comp appendChild [$doc createElement vevent]]
            set vprop [$vevent appendChild [$doc createElement properties]]
            $vprop appendChild [my createProp $doc uid text $now-$person]
            $vprop appendChild [my createProp $doc dtstamp date-time $now]
            $vprop appendChild [my createProp $doc dtstart date $start]
            $vprop appendChild [my createProp $doc summary text $person]

            set rrule [$vprop appendChild [$doc createElement rrule]]
            $rrule appendChild [my createProp $doc recur freq YEARLY]
        }

        puts [$doc asXML -xmlDeclaration true -encString utf-8]

        $doc delete
    }
}

