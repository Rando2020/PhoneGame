// UNVERIFIED: written without a Mac; never compiled or run. See README.md.
#include "meld_access.h"

#import <UIKit/UIKit.h>

MeldAccess *MeldAccess::instance = nullptr;

MeldAccess *MeldAccess::get_singleton() {
	return instance;
}

void MeldAccess::_bind_methods() {
	ClassDB::bind_method(D_METHOD("reduce_motion"), &MeldAccess::reduce_motion);
	ClassDB::bind_method(D_METHOD("content_size"), &MeldAccess::content_size);
	ADD_SIGNAL(MethodInfo("changed"));
}

bool MeldAccess::reduce_motion() const {
	return UIAccessibilityIsReduceMotionEnabled();
}

String MeldAccess::content_size() const {
	// e.g. "UICTContentSizeCategoryL"; the game maps it in Menus.text_step_for()
	NSString *cat = [UIApplication sharedApplication].preferredContentSizeCategory;
	return String::utf8([cat UTF8String]);
}

void MeldAccess::notify_changed() {
	// notifications arrive on the main queue (see below), the same thread as Godot's main loop on iOS
	emit_signal("changed");
}

MeldAccess::MeldAccess() {
	ERR_FAIL_COND(instance != nullptr);
	instance = this;
	NSMutableArray *tokens = [NSMutableArray array];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSArray *names = @[ UIAccessibilityReduceMotionStatusDidChangeNotification,
		UIContentSizeCategoryDidChangeNotification ];
	for (NSString *name in names) {
		id token = [nc addObserverForName:name
								   object:nil
									queue:[NSOperationQueue mainQueue]
							   usingBlock:^(NSNotification *note) {
								   if (MeldAccess::instance) {
									   MeldAccess::instance->notify_changed();
								   }
							   }];
		[tokens addObject:token];
	}
	observers = (__bridge_retained void *)tokens;
}

MeldAccess::~MeldAccess() {
	if (observers) {
		NSMutableArray *tokens = (__bridge_transfer NSMutableArray *)observers;
		for (id token in tokens) {
			[[NSNotificationCenter defaultCenter] removeObserver:token];
		}
		observers = nullptr;
	}
	if (instance == this) {
		instance = nullptr;
	}
}
