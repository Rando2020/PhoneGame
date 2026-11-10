// Compiled in CI (.github/workflows/ios-plugins.yml, ios-build.yml); never run on a device.
// The entry points named in meld_access.gdip.
#include "core/config/engine.h"
#include "meld_access.h"

static MeldAccess *meld_access = nullptr;

void init_meld_access() {
	meld_access = memnew(MeldAccess);
	Engine::get_singleton()->add_singleton(Engine::Singleton("MeldAccess", meld_access));
}

void deinit_meld_access() {
	if (meld_access) {
		memdelete(meld_access);
		meld_access = nullptr;
	}
}
