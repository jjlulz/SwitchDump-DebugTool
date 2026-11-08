export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:12.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SwitchDump
SwitchDump_FILES = Tweak.xm
SwitchDump_CFLAGS = -fobjc-arc
SwitchDump_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
