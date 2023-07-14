GCC_NAME=gcc-13.1.0
GCC_TARBALL=${GCC_NAME}.tar.xz
GCC_URL=ftp://anonymous@ftp.gnu.org/gnu/gcc/${GCC_NAME}/${GCC_TARBALL}

MPFR_NAME=mpfr-4.2.0
MPFR_TARBALL=${MPFR_NAME}.tar.xz
MPFR_URL=ftp://anonymous@ftp.gnu.org/gnu/mpfr/${MPFR_TARBALL}

GMP_NAME=gmp-6.2.1
GMP_TARBALL=${GMP_NAME}.tar.xz
GMP_URL=ftp://anonymous@ftp.gnu.org/gnu/gmp/${GMP_TARBALL}

MPC_NAME=mpc-1.3.1
MPC_TARBALL=${MPC_NAME}.tar.gz
MPC_URL=ftp://anonymous@ftp.gnu.org/gnu/mpc/${MPC_TARBALL}

BINUTILS_NAME=binutils-2.40
BINUTILS_TARBALL=${BINUTILS_NAME}.tar.xz
BINUTILS_URL=ftp://anonymous@ftp.gnu.org/gnu/binutils/${BINUTILS_TARBALL}

ARCH_TARBALL=ArchLinuxARM-rpi-armv7-latest.tar.gz
ARCH_URL=http://os.archlinuxarm.org/os/${ARCH_TARBALL}

PREFIX=/opt/armv7-linux-gnueabihf-gcc
DESTDIR=${PWD}/dist

DIRS=	\
	stamp \
	distfiles \
	build \
	src \
	${DESTDIR} \
	${DESTDIR}${PREFIX}/root

.PHONY: all clean

all: armv7hf-archlinux-gcc.tar.xz

stamp/fetch-gcc:
	-mkdir -p ${DIRS}
	fetch -o distfiles/${GCC_TARBALL} ${GCC_URL}
	-touch stamp/fetch-gcc

stamp/fetch-gccdeps:
	-mkdir -p ${DIRS}
	fetch -o distfiles/${MPFR_TARBALL} ${MPFR_URL}
	fetch -o distfiles/${MPC_TARBALL} ${MPC_URL}
	fetch -o distfiles/${GMP_TARBALL} ${GMP_URL}
	-touch stamp/fetch-gccdeps

stamp/extract-gccdeps: stamp/extract-gcc stamp/fetch-gccdeps
	-mkdir -p ${DIRS}
	tar -C src -x -f distfiles/${MPFR_TARBALL}
	tar -C src -x -f distfiles/${MPC_TARBALL}
	tar -C src -x -f distfiles/${GMP_TARBALL}
	cd src/${GCC_NAME} && ln -s ../${MPFR_NAME} mpfr && cd ../..
	cd src/${GCC_NAME} && ln -s ../${MPC_NAME} mpc && cd ../..
	cd src/${GCC_NAME} && ln -s ../${GMP_NAME} gmp && cd ../..
	-touch stamp/extract-gccdeps

stamp/extract-gcc: stamp/fetch-gcc
	-mkdir -p ${DIRS}
	tar -C src -x -f distfiles/${GCC_TARBALL}
	-touch stamp/extract-gcc

stamp/fetch-archroot:
	-mkdir -p ${DIRS}
	fetch -o distfiles/${ARCH_TARBALL} ${ARCH_URL}
	-touch stamp/fetch-archroot

stamp/extract-archroot: stamp/fetch-archroot
	-mkdir -p ${DIRS}
	tar -C ${DESTDIR}${PREFIX}/root -x -f distfiles/${ARCH_TARBALL} ./usr/lib\* ./usr/include\*
	-rm -rf ${DESTDIR}${PREFIX}/root/usr/lib/firmware \
		${DESTDIR}${PREFIX}/root/usr/lib/systemd \
		${DESTDIR}${PREFIX}/root/usr/lib/initcpio \
		${DESTDIR}${PREFIX}/root/usr/lib/modules
	-mkdir ${DESTDIR}${PREFIX}/root/lib
	cd ${DESTDIR}${PREFIX}/root/lib && ln -s ../usr/lib/ld-linux-armhf.so.3 ld-linux-armhf.so.3 && cd -
	-touch stamp/extract-archroot

stamp/fetch-binutils:
	-mkdir -p ${DIRS}
	fetch -o distfiles/${BINUTILS_TARBALL} ${BINUTILS_URL}
	-touch stamp/fetch-binutils

stamp/extract-binutils: stamp/fetch-binutils
	-mkdir -p ${DIRS}
	tar -C src -x -f distfiles/${BINUTILS_TARBALL}
	-touch stamp/extract-binutils

stamp/build-binutils: stamp/extract-binutils stamp/extract-archroot
	-mkdir -p ${DIRS}
	-mkdir -p build/${BINUTILS_NAME}
	cd build/${BINUTILS_NAME} && \
		CC=cc CXX=c++ \
			../../src/${BINUTILS_NAME}/configure \
			--prefix=${PREFIX} \
			--with-sysroot=${PREFIX}/root \
			--with-build-sysroot=${DESTDIR}${PREFIX}/root \
			--target=armv7-linux-gnueabihf \
			--host=amd64-unknown-freebsd`uname -r | sed 's|\-RELEASE$$||'` \
			--disable-nls \
			--disable-multilib && \
		gmake -j ${.MAKE.JOBS} V=1 all && \
		gmake -j ${.MAKE.JOBS} DESTDIR=${DESTDIR} install && \
		cd ../.. && \
		touch stamp/build-binutils

stamp/build-gcc: stamp/extract-gcc stamp/extract-gccdeps stamp/build-binutils
	-mkdir -p ${DIRS}
	-mkdir -p build/${GCC_NAME}
	cd build/${GCC_NAME} && \
		CC=cc CXX=c++ \
			../../src/${GCC_NAME}/configure \
			--prefix=${PREFIX} \
			--with-sysroot=${PREFIX}/root \
			--with-build-sysroot=${DESTDIR}${PREFIX}/root \
			--host=amd64-unknown-freebsd`uname -r | sed 's|\-RELEASE$$||'` \
			--target=armv7-linux-gnueabihf \
			--disable-nls \
			--disable-multilib \
			--with-cpu=cortex-a53 \
			--with-float=hard \
			--disable-bootstrap \
			--enable-languages=c,c++,fortran \
			--disable-lto && \
		gmake -j ${.MAKE.JOBS} V=1 all && \
		gmake -j ${.MAKE.JOBS} DESTDIR=${DESTDIR} install && \
		cd ../.. && \
		touch stamp/build-gcc

armv7hf-archlinux-gcc.tar.xz: stamp/build-gcc
	tar -C dist -c -v -f - \. | xz -9 -T6 > armv7hf-archlinux-gcc.tar.xz

clean:
	-rm -rf ${DIRS}
