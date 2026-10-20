// UNVERIFIED: written without a Mac; never compiled or run. See README.md.
#include "core/config/engine.h"
#include "meld_store.h"

static MeldStore *meld_store = nullptr;

void init_meld_store() {
	meld_store = memnew(MeldStore);
	Engine::get_singleton()->add_singleton(Engine::Singleton("MeldStore", meld_store));
}

void deinit_meld_store() {
	if (meld_store) {
		memdelete(meld_store);
		meld_store = nullptr;
	}
}
