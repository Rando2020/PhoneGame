// MeldStore: the App Store for the game, as an Engine singleton "MeldStore".
//   products() -> Array of {id, price}   (empty until the store answers)
//   purchase(id)                          -> signal purchased(id) or failed(id, reason)
//   restore()                             -> signal restored(ids)
// The game side: godot/engine/entitlement.gd, godot/ui/run_flow.gd.
// UNVERIFIED: written without a Mac; never compiled or run.
#ifndef MELD_STORE_H
#define MELD_STORE_H

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/array.h"

class MeldStore : public Object {
	GDCLASS(MeldStore, Object);

	static MeldStore *instance;
	Array product_list;

protected:
	static void _bind_methods();

public:
	static MeldStore *get_singleton();
	Array products() const;
	void purchase(String id);
	void restore();

	void _set_products(const Array &list);

	MeldStore();
	~MeldStore();
};

#endif
