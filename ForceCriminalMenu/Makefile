ARCHS = arm64
TARGET = iphone:clang:15.0:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ForceCriminalMenu
ForceCriminalMenu_FILES = FCMMain.xm
ForceCriminalMenu_FRAMEWORKS = UIKit
ForceCriminalMenu_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
