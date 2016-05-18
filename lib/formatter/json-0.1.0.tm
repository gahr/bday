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
package require json::write

package provide formatter::json 0.1.0

# This class provides a formatter to produce JSON output
oo::class create formatter::json {

    variable beautify

    ##
    # Construct a JSON formatter. The configuration consists in a list of
    # supported keywords. Currently:
    #
    # Key       Meaning
    # beautify  Beautify JSON output
    constructor {config} {
        variable beautify

        if {[lsearch -exact $config beautify] != -1} {
            set beautify true
        } else {
            set beautify false
        }
    }

    ##
    # Print a list of birthdays as a JSON array. Each element is a birthday,
    # with properties person and birthday.
    method print {l} {
        variable beautify

        ::json::write indented $beautify
        ::json::write aligned $beautify
        set out [list]
        foreach entry $l {
            set person [dict get $entry person]
            set birthday [dict get $entry birthday]
            lassign [::datelib::parseDate $birthday] y m d
            lappend out [::json::write object \
                person   [::json::write string $person] \
                birthday [::json::write string $m-$d]]
        }
        
        puts [::json::write array {*}$out]
    }
}

