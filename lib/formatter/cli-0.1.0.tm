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

package provide formatter::cli 0.1.0

# This class provides a formatter to print birthday information to standard
# output, in a way that is suitable for rendering in a CLI.
oo::class create formatter::cli {

    variable fmt

    ##
    # Construct a cli formatter.
    # Configuration consists of a string specifying format groups:
    # %A(str)     Person's age in years at the next birthday. Str is printed
    #             only if the person's birthyear is known. Inside str, $ is
    #             substituted by the computed age. Use $$ to print $ verbatim.
    #             Example: %A(turns $ years old).
    # %Y(str)     Like %A, but print the birthyear, if known.
    # %B(fmt)     Next birthday, where x can be anything accepted by Tcl's
    #             [clock format] command.
    # %N          Person's name.
    # %D          Number of days from today to the next birthday, space-padded
    #             to three characters.
    # %d          Same as %D, but with no padding.
    # %E          Same as %D, but negative and padded to four characters.
    # %e          Same as %E, but with no padding.
    # %f          Number of days from today to the next birthday, in an easy to
    #             read format.
    #             and other numbers are printed as 'in X days'.
    # %%          Can be used to print the % character verbatim.
    constructor {config} {
        variable fmt
        set fmt $config
    }

    ##
    # Extract a substring from nesting parenthesis. Return a list with the id
    # past the closing parenthesis and the extracted substring.
    method deparenthesize {charList idx} {
        set c [lindex $charList [incr idx]]
        incr idx
        if {$c ne {(}} {
            return {}
        }
        set endIdx [lsearch -start $idx $charList )]
        if {$endIdx == -1} {
            return {}
        }
        list $endIdx [join [lrange $charList $idx $endIdx-1] {}]
    }

    ##
    # Re-insert backslash-escaped characters in a string
    method escapize {str} {
        string map { \\t \u0009 \\n \u000a \\r \u000d } $str
    }

    ##
    # Print a list of entries to stdout.
    method print {l} {
        variable fmt

        foreach entry $l {
            set person   [dict get $entry person]
            set birthday [dict get $entry birthday]

            scan [lindex [::datelib::parseDate $birthday] 0] %d year
            set nextDate [::datelib::next $birthday]

            set out {}
            set fmtList [split $fmt {}]
            set fmtLength [llength $fmtList]
            for {set idx 0} {$idx < $fmtLength} {incr idx} {
                set c [lindex $fmtList $idx]

                # Not a format character. Print the character verbatim.
                if {$c ne {%}} {
                    append out $c
                    continue
                }

                # We got a format character. Let's parse what comes next.
                set c [lindex $fmtList [incr idx]]
                switch $c {
                    % { append out % }
                    N { append out $person }
                    A - Y {
                        lassign [my deparenthesize $fmtList $idx] idx subFmt
                        if {$idx eq {}} {
                            return -code error "Invalid ${c}(...) format: $fmt"
                        }
                        if {$year == 0} {
                            # Birthyear not known
                            continue
                        }
                        if {$c eq {A}} {
                            set cur [::datelib::cfmt %Y $nextDate]
                            set val [expr {$cur - $year}]
                        } else {
                            set val $year
                        }
                        append out [string map [list $ $val] $subFmt]
                    }
                    B {
                        lassign [my deparenthesize $fmtList $idx] idx subFmt
                        if {$idx eq {}} {
                            return -code error "Invalid B(..) format: $fmt"
                        }
                        append out [::datelib::cfmt $subFmt $nextDate]
                    }
                    D - d - E - e - f {
                        set now [::datelib::cscn %m%d [::datelib::cfmt %m%d]]
                        set days [expr {($nextDate - $now) / 86400}]
                        switch $c {
                            D {
                                set days [format {% 3s} $days]
                            }
                            E {
                                set days [format {% 4s} -$days]
                            }
                            e {
                                set days -$days
                            }
                            f {
                                if {$days == 0} {
                                    set days today
                                } elseif {$days == 1} {
                                    set days tomorrow
                                } elseif {$days < 7} {
                                    set days "in $days days"
                                } elseif {$days < 30} {
                                    set days "in [expr {$days / 7}] weeks"
                                } else {
                                    set days "in [expr {$days / 30}] months"
                                }
                            }
                        }
                        append out $days
                    }
                }
            }
            puts [my escapize $out]
        }
    }
}

