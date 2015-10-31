DEBUG = 0

PACKAGE_VERSION = 1.1.3-1

THEOS_DEVICE_IP = 192.168.1.105

TARGET := iphone:clang
ARCHS = armv7 armv7s arm64

export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 8.0
export ADDITIONAL_OBJCFLAGS = -fobjc-arc -fvisibility=default -fvisibility-inlines-hidden -O2

LIBRARY_NAME = libqrc
libqrc_LOGOSFLAGS = -c generator=internal
libqrc_FILES = QRC.xm MessageHandler.m Helper.m hud.m ContactsViewController.m PhotoPickerController.m Categories.m
libqrc_INSTALL_PATH = /usr/lib/
libqrc_FRAMEWORKS = UIKit Foundation CoreFoundation CoreGraphics QuartzCore AudioToolbox MobileCoreServices Photos AddressBook
libqrc_PRIVATE_FRAMEWORKS = ChatKit BulletinBoard IMCore BackBoardServices SpringBoardServices
libqrc_LIBRARIES = substrate

BUNDLE_NAME = QRCSettings
QRCSettings_FILES = $(wildcard Settings/*.m)
QRCSettings_INSTALL_PATH = /Library/PreferenceBundles
QRCSettings_FRAMEWORKS = UIKit
QRCSettings_PRIVATE_FRAMEWORKS = Preferences

ADDITIONAL_CFLAGS += -I/iPhoneHeaders

ifeq ($(DEBUG), 1)
    ADDITIONAL_CFLAGS += -DDEBUG
else
    ADDITIONAL_CFLAGS += -DNDEBUG
endif

include ~/theos/makefiles/common.mk

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/bundle.mk

internal-after-install::
	install.exec "killall -9 backboardd SpringBoard"