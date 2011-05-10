#/bin/env bash

# .------------------------------------------------------.
# | tachyon toolchain bootstrap and environment scripts  |
# '------------------------------------------------------'

# the tools array implicitly defines the build order, so be sure to keep those aligned.
# each entry has this format: <name>:<version>:<configure flags>:<all target>:<install target>

tools=(
    "binutils:2.21:--target=x86_64-pc-elf"
    "gmp:5.0.2:"
    "mpfr:3.0.1:"
    "mpc:0.9:--with-gmp=\${_tt_prefix} --with-mpfr=\${_tt_prefix}"
    "gcc:4.6.0:--with-gnu-ld --with-gnu-as --with-mpfr=\${_tt_prefix} --with-gmp=\${_tt_prefix} --with-mpc=\${_tt_prefix}:all-gcc:install-gcc"
    "gdb:7.2:--target=x86_64-pc-linux-gnu --disable-werror"
    "cgdb:0.6.5:"
    "grub:1.99~rc2:"
    "xorriso:1.0.8:"
    "qemu:0.14.1:--disable-user --enable-system --enable-curses --enable-sdl --target-list=i386-softmmu,x86_64-softmmu --enable-debug"
    "bochs:2.4.6:--with-sdl --with-x11 --with-x --enable-x86-64 --enable-smp --enable-long-phy-address --enable-cpu-level=6 --enable-x2apic --enable-debugger --enable-logging --enable-vbe --enable-pci"
)

function info()  { [[ ${_tt_verbose} == true ]] && echo ">>> " "$@"; }
function warn()  { echo "!!! " "$@"; }
function error() { echo "*** " "$@"; }
function fatal() { error "$@"; exit 1; }

function tt_exit_help() {
    echo "${help}"

    exit $1
}

function tt_split() {
    local packed="$1"

    save_IFS=$IFS
    IFS=':'

    local unpacked=( ${packed} )
    echo "${unpacked[@]}"
}

_tt_home="$(cd "$(dirname "$0")"; pwd)"
_tt_verbose=false
_tt_build=false
_tt_source="${_tt_home}/.source"
_tt_bdir="${_tt_home}/.build"
_tt_prefix="$(cd "${_tt_home}/.."; pwd)/.package"
_tt_preflight=false
_tt_clean=false
_tt_jobs=1

help="$0 usage:

   --help                  print this message.
   -v | --verbose          verbose output.
   -b | --build            build the tools (as opposed to setting environment only).
   -j <j> | --jobs=<j>     use 'j' jobs during builds.
   --clean                 remove existing build directories before building.
   --preflight             check package completeness (source availability) before
                           starting the builds.
   -s <s> | --source=s     use 's' as source directory containing the tools sources.
                           defaults to '${_tt_source}'.
   -t <t> | --temp=<t>     use 't' as temporary build directory.
                           defaults to '${_tt_bdir}'.
   --version=<t>:<v>       use specified version 'v' for tool 't'. for example to use
                           gcc-4.5.2, give --version=gcc:4.5.2
   --configure=<t>:<f>     use configure flags 'f' for tool 't'
   -p <p> | --prefix=<p>   define the prefix where to install all the tools. defaults
                           to '${_tt_prefix}'."

# .------------------------------------------.
# | parses the command line parameters given |
# | to the script.                           |
# '------------------------------------------'
function tt_parse_cl() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        "-v"|"--verbose")   _tt_verbose=true                ;;
        "-b"|"--build")     _tt_build=true                  ;;
        "-s")               shift; _tt_source="$1"          ;;
        "--source="*)       _tt_source="${1#--source=}"     ;;
        "-p")               shift; _tt_prefix="$1"          ;;
        "--prefix="*)       _tt_prefix="${1#--prefix=}"     ;;
        "-t")               shift; _tt_bdir="$1"            ;;
        "--temp="*)         _tt_bdir="${1#--temp=}"         ;;
        "-j")               shift; _tt_jobs="$1"            ;;
        "-j"[0-9]*)         _tt_jobs="${1#-j}"              ;;
        "--jobs=")          _tt_jobs="${1#--jobs=}"         ;;
        "--preflight")      _tt_preflight=true              ;;
        "--clean")          _tt_clean=true                  ;;
        "--debug")          set -xv                         ;;
        "--help")           tt_exit_help 0                  ;;
        *)                  error "unknown argument: '$1'";
                            tt_exit_help 1                  ;;
        esac
        shift
    done
}

# .--------------------------------------------.
# | creates and changes to the build directory |
# | for the given package.                     |
# '--------------------------------------------'
function tt_build_dir() {
    local dir="${_tt_bdir}/${_tt_cur_name}-${_tt_cur_version}"

    [[ -d ${dir} && ${_tt_clean} == false ]] && fatal "build directory ${dir} exists."
    [[ -d ${dir} ]] && rm -rf ${dir}

    mkdir -p "${dir}"
    cd "${dir}"
}

# .--------------------------------------------.
# | finds the source package for the given tool|
# '--------------------------------------------'
function tt_find_source() {
    for file in ${_tt_source}/${_tt_cur_name}-${_tt_cur_version}.*; do
        if [[ ${file} == *.tar.gz || ${file} == *.tar.bz2 || ${file} == *.tgz ]]; then
            echo "${file}"
            return
        fi
    done
}

# .--------------------------------------------.
# | unpacks the source package into the build  |
# | directory.                                 |
# '--------------------------------------------'
function tt_unpack() {
    info "unpacking ${_tt_cur_name}-${_tt_cur_version}"

    tt_build_dir || fatal "cannot create build directory!"

    local tflags=

    case "${_tt_cur_src}" in
    *.tgz|*.tar.gz) tflags="xfz";;
    *.tar.bz2)      tflags="xfj";;
    esac

    tar ${tflags} "${_tt_cur_src}"
    cd ${_tt_cur_name}* || fatal "missing expected directory"
}

# .--------------------------------------------.
# | configures the current package.            |
# '--------------------------------------------'
function tt_configure() {
    info "configuring ${_tt_cur_name}-${_tt_cur_version}"

    [[ $(pwd) == ${_tt_bdir}/* ]] \
        || fatal "oups. configuring outside the build dir?"

    [[ -x ./configure ]] \
        || fatal "oups. cannot find configure script"

    ./configure --prefix=${_tt_prefix} $(echo ${_tt_cur_flags})
}

# .--------------------------------------------.
# | builds the current package.                |
# '--------------------------------------------'
function tt_build() {
    info "building ${_tt_cur_name}-${_tt_cur_version}"
    make -j${_tt_jobs} ${_tt_cur_build_target}
}

# .--------------------------------------------.
# | installs the current package.              |
# '--------------------------------------------'
function tt_install() {
    info "installing ${_tt_cur_name}-${_tt_cur_version}"
    make -j${_tt_jobs} ${_tt_cur_install_target}
}

_tt_cur_name=
_tt_cur_version=
_tt_cur_flags=
_tt_cur_bdir=
_tt_cur_src=
_tt_cur_build_target=
_tt_cur_install_target=

# .--------------------------------------------.
# | assures that all required information for  |
# | the current package is available.          |
# '--------------------------------------------'
function tt_assure_complete() {
    [[ -n "${_tt_cur_name}" ]] || fatal "package not complete: name missing"
    [[ -n "${_tt_cur_version}" ]] || fatal "${_tt_cur_name} not complete: version missing"
    [[ -n "${_tt_cur_src}" ]] || fatal "${_tt_cur_name} not complete: source missing"

    info "package ${_tt_cur_name} seems complete ..."
}

# .--------------------------------------------.
# | parses a packages information and sets the |
# | global package information variables to    |
# | according values.                          |
# '--------------------------------------------'

function tt_use_package() {
    local pkginfo="$1"
    local sIFS=${IFS}
    IFS=':'
    local pkg=( ${pkginfo} )
    IFS=${sIFS}

    _tt_cur_name="${pkg[0]}"
    _tt_cur_version="${pkg[1]}"
    _tt_cur_flags="${pkg[2]}"
    _tt_cur_build_target="${pkg[3]}"
    _tt_cur_install_target="${pkg[4]}"
    _tt_cur_src="$(tt_find_source)"
    _tt_cur_bdir="${_tt_bdir}/${_tt_cur_name}"

    tt_assure_complete
}

tt_parse_cl "$@"

if [[ ${_tt_preflight} == true ]]; then
    for package in "${tools[@]}"; do
        tt_use_package "${package}"
    done
fi

if [[ ${_tt_build} == true ]]; then
    for package in "${tools[@]}"; do
        tt_use_package "${package}"
        tt_unpack || fatal "failed to unpack ${_tt_cur_name}-${_tt_cur_version}"
        tt_configure || fatal "failed to configure ${_tt_cur_name}-${_tt_cur_version}"
        tt_build || fatal "failed to build ${_tt_cur_name}-${_tt_cur_version}"
        tt_install || fatal "failed to install ${_tt_cur_name}-${_tt_cur_version}"
    done
else
    # TODO: argl...
    export PATH=${_tt_prefix}/bin:${PATH}
fi

