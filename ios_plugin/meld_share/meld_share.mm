// UNVERIFIED: written without a Mac; never compiled or run. See README.md.
#include "meld_share.h"

#import <UIKit/UIKit.h>

MeldShare *MeldShare::instance = nullptr;

MeldShare *MeldShare::get_singleton() {
	return instance;
}

void MeldShare::_bind_methods() {
	ClassDB::bind_method(D_METHOD("share_image", "path"), &MeldShare::share_image);
	ADD_SIGNAL(MethodInfo("finished", PropertyInfo(Variant::BOOL, "completed")));
}

void MeldShare::_finished(bool completed) {
	emit_signal("finished", completed);
}

// The top view controller that can present (Godot's root, or whatever it presents).
static UIViewController *top_vc() {
	UIWindow *win = nil;
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if ([scene isKindOfClass:[UIWindowScene class]]) {
			for (UIWindow *w in ((UIWindowScene *)scene).windows) {
				if (w.isKeyWindow) { win = w; break; }
			}
		}
		if (win) break;
	}
	UIViewController *vc = win.rootViewController;
	while (vc.presentedViewController) vc = vc.presentedViewController;
	return vc;
}

void MeldShare::share_image(String path) {
	NSString *p = [NSString stringWithUTF8String:path.utf8().get_data()];
	UIImage *img = [UIImage imageWithContentsOfFile:p];
	if (img == nil) {
		_finished(false);
		return;
	}
	MeldShare *self_ref = this;
	dispatch_async(dispatch_get_main_queue(), ^{
		UIActivityViewController *sheet =
				[[UIActivityViewController alloc] initWithActivityItems:@[ img ] applicationActivities:nil];
		sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *err) {
			self_ref->_finished(completed);
		};
		UIViewController *vc = top_vc();
		// iPad: the sheet is a popover and needs an anchor, or UIKit throws
		if (sheet.popoverPresentationController) {
			sheet.popoverPresentationController.sourceView = vc.view;
			sheet.popoverPresentationController.sourceRect =
					CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMaxY(vc.view.bounds) - 80, 1, 1);
			sheet.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionDown;
		}
		[vc presentViewController:sheet animated:YES completion:nil];
	});
}

MeldShare::MeldShare() {
	instance = this;
}

MeldShare::~MeldShare() {
	if (instance == this) instance = nullptr;
}
