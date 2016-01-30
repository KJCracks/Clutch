# Target specific variables
TARGET := clutch
ENTITLEMENTS := Clutch.entitlements
PCH := Clutch-Prefix.pch
SRC_DIRS := MiniZip
CFLAGS += -fmodules -fobjc-arc -I..
LDFLAGS += -lz -F/System/Library/PrivateFrameworks -F /System/Library/Frameworks -framework AppSupport -framework Foundation -framework MobileCoreServices
LDLIBS = -lncurses

# Macro to find all source files in a directory
get_srcs = $(wildcard $1*.[cm]) $(wildcard $1*.cpp) $(wildcard $1*.mm)

# General build path variables
BUILD := build
SRCS := $(call get_srcs,) $(foreach d,$(SRC_DIRS),$(call get_srcs,$d/))
OBJS := $(patsubst %,$(BUILD)/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)
BUILD_DIR_RULES := $(BUILD)/.dir $(patsubst %,$(BUILD)/%/.dir,$(SRC_DIRS))

# Tools and flags to use
XCRUN := xcrun --sdk iphoneos
CLANG := $(XCRUN) clang
CLANGXX := $(XCRUN) clang++
ARCHFLAGS := -arch armv7 -arch armv7s -arch arm64
CC := $(CLANG) $(ARCHFLAGS)
LD := $(CLANGXX) $(ARCHFLAGS)
CFLAGS += -include $(PCH) -I. $(foreach sd,$(SRC_DIRS),-I$(sd)) -UNDEBUG
CODESIGN := $(XCRUN) codesign
CSFLAGS := -fs-

# Print all commands executed when VERBOSE is defined
ifdef VERBOSE
_v :=
else
_v := @
endif


# Build the target by default
all: $(TARGET)

# Build in debug mode (with asserts enabled)
debug: override CFLAGS += -ggdb -DDEBUG=1
debug: override OFLAGS :=
debug: $(TARGET)

# Uses clang's Address Sanitizer to help detect memory errors
debug+: override CFLAGS += -ggdb -DDEBUG=1 -fsanitize=address
debug+: override OFLAGS :=
debug+: override LDFLAGS += -fsanitize=address
debug+: debug


# Linking rule
$(BUILD)/$(TARGET).unsigned: $(OBJS)
	@echo 'Linking $(@F)'
	$(_v)$(LD) $(LDFLAGS) -o $@ $^

# Signing rule
$(TARGET): $(BUILD)/$(TARGET).unsigned
	@echo 'Signing $@'
	$(_v)$(CODESIGN) $(CSFLAGS) --entitlements $(ENTITLEMENTS) $< && cp $< $@


# Compiling rule
$(BUILD)/%.o: % | $(BUILD_DIR_RULES)
	@echo 'Compiling $<'
	$(_v)$(CC) $(CFLAGS) $(OFLAGS) -I$(<D) -MD -MP -MF $(BUILD)/$*.d -c -o $@ $<


# Build dependency rules
-include $(DEPS)


# Make sure that the .dir files aren't automatically deleted after building
.SECONDARY:

# Directory creation rule
%/.dir:
	$(_v)mkdir -p $* && touch $@

# Build products cleaning rule
clean:
	@echo 'Removing built products'
	$(_v)rm -rf $(BUILD) $(TARGET)

.PHONY: all debug debug+ clean
