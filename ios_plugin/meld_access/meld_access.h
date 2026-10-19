// MeldAccess: the two iOS accessibility settings Godot 4.3 can't read.
// Registers an engine singleton "MeldAccess" that the game finds with
// Engine.has_singleton("MeldAccess") (godot/ui/front/menus.gd, os_access()).
//   reduce_motion() -> bool     UIAccessibility.isReduceMotionEnabled
//   content_size()  -> String   UIApplication.preferredContentSizeCategory
//   signal changed               either setting changed in iOS Settings
// UNVERIFIED: written without a Mac; never compiled or run.
#ifndef MELD_ACCESS_H
#define MELD_ACCESS_H

#include "core/object/class_db.h"
#include "core/object/object.h"

class MeldAccess : public Object {
	GDCLASS(MeldAccess, Object);

	static MeldAccess *instance;
	void *observers = nullptr; // NSMutableArray of notification tokens (retained)

protected:
	static void _bind_methods();

public:
	static MeldAccess *get_singleton();
	bool reduce_motion() const;
	String content_size() const;
	void notify_changed();

	MeldAccess();
	~MeldAccess();
};

#endif
