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

package provide provider::textfile 0.1.0

# This class provides an implementation of a data provider backed by a
# plain-text file. Data is serialized as a dictionary where keys are people and
# values are birthdays in yyyy-mm-dd format.
#
oo::class create provider::textfile {

    variable filepath

    ##
    # Construct a plain-text backed provider.
    # Configuration MUST include
    # - path The path of the file used for storage.
    constructor {config} {
        variable filepath

        set filepath [dict get $config path]

    }

    ##
    # Set or modify a person's birthday.
    method setBirthday {person birthday} {
        set datadict [my load]
        dict set datadict $person $birthday
        my store $datadict
        return
    }

    ##
    # Return a person's birthday, or the empty string if person wasn't found.
    method getBirthday {person} {
        set datadict [my load]
        if {![catch {dict get $datadict $person} birthday]} {
            return $birthday
        }
        return
    }

    ##
    # Remove a person's birthday
    method remove {person} {
        set datadict [my load]
        set datadict [dict remove $datadict $person]
        my store $datadict
    }

    ##
    # Return the content of the database. Only the basic "person" and
    # "birthday" attribute is supported by this implementation.
    method get {} {
        set datadict [my load]

        set d [list]
        foreach {p b} $datadict {
            lappend d [dict create person $p birthday $b]
        }
        return $d
    }

    ##
    # Load and return the datadict
    method load {} {
        set fd [open $filepath {RDONLY CREAT}]
        set datadict [read $fd]
        close $fd
        return $datadict
    }

    ##
    # Serialize to persistent storage.
    method store {datadict} {
        variable filepath

        set fd [open $filepath w]
        puts $fd $datadict
        close $fd
    }
}

