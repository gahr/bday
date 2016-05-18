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
package require lmdb 0.3.4

package provide provider::lmdb 0.1.0

# This class provides an implementation of a data provider backed by an LMDB
# database.
#
oo::class create provider::lmdb {

    variable myenv
    variable mydbi

    ##
    # Construct an LMDB based provider.
    # Configuration MUST include
    # - path The path of the file used for storage.
    constructor {config} {
        variable myenv
        variable mydbi

        set myenv [lmdb env]
        try {
            $myenv open -path [dict get $config path] -nosubdir 1 -fixedmap 0
        } on error msg {
            return -code error $msg
        }
        set mydbi [lmdb open -env $myenv]
    }

    ## Cleanup
    destructor {
        variable myenv
        variable mydbi

        $mydbi close -env $myenv
        $myenv close
    }

    ##
    # Set or modify a person's birthday.
    method setBirthday {person birthday} {
        variable myenv
        variable mydbi

        set txn [$myenv txn]
        $mydbi put $person $birthday -txn $txn
        $txn commit
        $txn close
        return
    }

    ##
    # Return a person's birthday, or the empty string if person wasn't found.
    method getBirthday {person} {
        variable myenv
        variable mydbi

        set txn [$myenv txn -readonly 1]
        set birthday [$mydbi get $person -txn $txn]
        $txn abort
        $txn close
        return $birthday
    }

    ##
    # Remove a person's birthday
    method remove {person} {
        variable myenv
        variable mydbi

        set txn [$myenv txn]
        $mydbi del $person {} -txn $txn
        $txn commit
        $txn close
        return
    }

    ##
    # Return the content of the database. Only the basic "person" and
    # "birthday" attribute is supported by this implementation.
    method get {} {
        variable myenv
        variable mydbi

        set txn [$myenv txn -readonly 1]
        set cur [$mydbi cursor -txn $txn]

        set d [list]
        while {[catch {set data [$cur get -next]} result] == 0} {
            lassign $data person birthday
            lappend d [dict create person $person birthday $birthday]
        }

        $cur close
        $txn abort
        $txn close
        return $d
    }

    ##
    # No-op. Data is saved as soon as it's set.
    method save {} { }
}

