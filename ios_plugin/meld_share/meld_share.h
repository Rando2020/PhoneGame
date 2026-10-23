// MeldShare: the iOS share sheet for one image, as an Engine singleton "MeldShare".
//   share_image(path)   path: an absolute file path to a PNG (the game passes
//                       ProjectSettings.globalize_path("user://run_card_....png"))
//   signal finished(completed: bool)   the sheet closed (true: something was done with it)
// The game side: godot/ui/fx/run_card.gd (RunCard.share), godot/ui/run_flow.gd.
// UNVERIFIED: written without a Mac; never compiled or run.
#ifndef MELD_SHARE_H
#define MELD_SHARE_H

#include "core/object/class_db.h"
#include "core/object/object.h"

class MeldShare : public Object {
	GDCLASS(MeldShare, Object);

	static MeldShare *instance;

protected:
	static void _bind_methods();

public:
	static MeldShare *get_singleton();
	void share_image(String path);
	void _finished(bool completed);

	MeldShare();
	~MeldShare();
};

#endif
