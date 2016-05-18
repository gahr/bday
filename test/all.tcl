package require tcltest
namespace import ::tcltest::*

configure {*}$argv -testdir [file dirname [info script]]
runAllTests
