# Out-of-tree build of hid-uclogic with Gaomon S620 (256c:006f) support
obj-m := hid-uclogic.o
hid-uclogic-objs := hid-uclogic-core.o hid-uclogic-rdesc.o hid-uclogic-params.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
