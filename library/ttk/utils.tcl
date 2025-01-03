#
# $Id: utils.tcl,v 1.5 2007/12/13 15:27:08 dgp Exp $
#
# Utilities for widget implementations.
#

### Focus management.
#

## ttk::takefocus --
#	This is the default value of the "-takefocus" option
#	for widgets that participate in keyboard navigation.
#
# See also: tk::FocusOK
#
proc ttk::takefocus {w} {
    expr {[$w instate !disabled] && [winfo viewable $w]}
}

## ttk::traverseTo $w --
# 	Set the keyboard focus to the specified window.
#
proc ttk::traverseTo {w} {
    set focus [focus]
    if {$focus ne ""} {
	event generate $focus <<TraverseOut>>
    }
    focus $w
    event generate $w <<TraverseIn>>
}

## ttk::clickToFocus $w --
#	Utility routine, used in <ButtonPress-1> bindings --
#	Assign keyboard focus to the specified widget if -takefocus is enabled.
#
proc ttk::clickToFocus {w} {
    if {[ttk::takesFocus $w]} { focus $w }
}

## ttk::takesFocus w --
#	Test if the widget can take keyboard focus:
#
#	+ widget is viewable, AND:
#	- if -takefocus is missing or empty, return 0, OR
#	- if -takefocus is 0 or 1, return that value, OR
#	- append the widget name to -takefocus and evaluate it
#	  as a script.
#
# See also: tk::FocusOK
#
# Note: This routine doesn't implement the same fallback heuristics 
#	as tk::FocusOK.
#
proc ttk::takesFocus {w} {

    if {![winfo viewable $w]} { return 0 }

    if {![catch {$w cget -takefocus} takefocus]} {
	switch -- $takefocus {
	    0  -
	    1  { return $takefocus }
	    "" { return 0 }
	    default {
		set value [uplevel #0 $takefocus [list $w]]
		return [expr {$value eq 1}]
	    }
	}
    }

    return 0
}

## ttk::focusFirst $w --
#	Return the first descendant of $w, in preorder traversal order,
#	that can take keyboard focus, "" if none do.
#
# See also: tk_focusNext
#

proc ttk::focusFirst {w} {
    if {[ttk::takesFocus $w]} { 
	return $w 
    }
    foreach child [winfo children $w] {
	if {[set c [ttk::focusFirst $child]] ne ""} {
	    return $c
	}
    }
    return ""
}

### Grabs.
#
# Rules:
#	Each call to [grabWindow $w] or [globalGrab $w] must be
#	matched with a call to [releaseGrab $w] in LIFO order.
#
#	Do not call [grabWindow $w] for a window that currently
#	appears on the grab stack.
#
#	See #1239190 and #1411983 for more discussion.
#
namespace eval ttk {
    variable Grab 		;# map: window name -> grab token

    # grab token details:
    #	Two-element list containing:
    #	1) a script to evaluate to restore the previous grab (if any);
    #	2) a script to evaluate to restore the focus (if any)
}

## SaveGrab --
#	Record current grab and focus windows.
#
proc ttk::SaveGrab {w} {
    variable Grab

    if {[info exists Grab($w)]} {
	# $w is already on the grab stack.
	# This should not happen, but bail out in case it does anyway:
	#
	return
    }

    set restoreGrab [set restoreFocus ""]

    set grabbed [grab current $w]
    if {[winfo exists $grabbed]} {
    	switch [grab status $grabbed] {
	    global { set restoreGrab [list grab -global $grabbed] }
	    local  { set restoreGrab [list grab $grabbed] }
	    none   { ;# grab window is really in a different interp }
	}
    }

    set focus [focus]
    if {$focus ne ""} {
    	set restoreFocus [list focus -force $focus]
    }

    set Grab($w) [list $restoreGrab $restoreFocus]
}

## RestoreGrab --
#	Restore previous grab and focus windows.
#	If called more than once without an intervening [SaveGrab $w],
#	does nothing.
#
proc ttk::RestoreGrab {w} {
    variable Grab

    if {![info exists Grab($w)]} {	# Ignore
	return;
    }

    # The previous grab/focus window may have been destroyed,
    # unmapped, or some other abnormal condition; ignore any errors.
    #
    foreach script $Grab($w) {
	catch $script
    }

    unset Grab($w)
}

## ttk::grabWindow $w --
#	Records the current focus and grab windows, sets an application-modal
#	grab on window $w.
#
proc ttk::grabWindow {w} {
    SaveGrab $w
    grab $w
}

## ttk::globalGrab $w --
#	Same as grabWindow, but sets a global grab on $w.
#
proc ttk::globalGrab {w} {
    SaveGrab $w
    grab -global $w
}

## ttk::releaseGrab --
#	Release the grab previously set by [ttk::grabWindow]
#	or [ttk::globalGrab].
#
proc ttk::releaseGrab {w} {
    grab release $w
    RestoreGrab $w
}

### Auto-repeat.
#
# NOTE: repeating widgets do not have -repeatdelay
# or -repeatinterval resources as in standard Tk;
# instead a single set of settings is applied application-wide.
# (TODO: make this user-configurable)
#
# (@@@ Windows seems to use something like 500/50 milliseconds
#  @@@ for -repeatdelay/-repeatinterval)
#

namespace eval ttk {
    variable Repeat
    array set Repeat {
	delay		300
	interval	100
	timer		{}
	script		{}
    }
}

## ttk::Repeatedly --
#	Begin auto-repeat.
#
proc ttk::Repeatedly {args} {
    variable Repeat
    after cancel $Repeat(timer)
    set script [uplevel 1 [list namespace code $args]]
    set Repeat(script) $script
    uplevel #0 $script
    set Repeat(timer) [after $Repeat(delay) ttk::Repeat]
}

## Repeat --
#	Continue auto-repeat
#
proc ttk::Repeat {} {
    variable Repeat
    uplevel #0 $Repeat(script)
    set Repeat(timer) [after $Repeat(interval) ttk::Repeat]
}

## ttk::CancelRepeat --
#	Halt auto-repeat.
#
proc ttk::CancelRepeat {} {
    variable Repeat
    after cancel $Repeat(timer)
}

### Miscellaneous.
#

## ttk::copyBindings $from $to --
#	Utility routine; copies bindings from one bindtag onto another.
#
proc ttk::copyBindings {from to} {
    foreach event [bind $from] {
	bind $to $event [bind $from $event]
    }
}

#*EOF*
