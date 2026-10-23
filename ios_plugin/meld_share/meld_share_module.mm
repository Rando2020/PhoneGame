// UNVERIFIED: written without a Mac; never compiled or run. See README.md.
#include "core/config/engine.h"
#include "meld_share.h"

static MeldShare *meld_share = nullptr;

void init_meld_share() {
	meld_share = memnew(MeldShare);
	Engine::get_singleton()->add_singleton(Engine::Singleton("MeldShare", meld_share));
}

void deinit_meld_share() {
	if (meld_share) {
		memdelete(meld_share);
		meld_share = nullptr;
	}
}
