THEOS = /opt/theos
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Distance
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = XDVipCrack
XDVipCrack_FILES = Tweak.xm
XDVipCrack_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
