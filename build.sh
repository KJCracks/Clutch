#! /bin/bash

while getopts ":ip: :h :d: :t" opt; do
    case $opt in
        ip)
            echo "IP: $OPTARG" >&2
            INSTALL_IP="$OPTARG"
            ;;
        d)
            echo "setting build directory: $OPTARG" >&2
            BUILD_DIR="$OPTARG"
            ;;
        h)
            echo "usage: [OPTIONS]"
            echo "-ip   IP to install build results to"
            echo "-d    set build directory"
            echo "-h    shows this help"
            exit 0
            ;;
        \?)
            echo "Unrecognized Option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "-$OPTARG requires argument" >&2
            exit 1
            ;;
    esac
done

PROJECT_DIR=$( pwd )

if [ -z ${BUILD_DIR+"0"} ]; then
    BUILD_DIR="${PROJECT_DIR}/build"
fi

TOOLCHAIN_FILE="${PROJECT_DIR}/cmake/iphoneos.toolchain.cmake"
CODESIGN=$( xcrun --sdk iphoneos --find codesign )
CLUTCH_ENTITLEMENTS="${PROJECT_DIR}/Clutch/Clutch.entitlements"
CLUTCH_BINARY="${PROJECT_DIR}/bin/Clutch"


# clean build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
pushd "${BUILD_DIR}"

cmake \
    -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE} \
    ${PROJECT_DIR}

cmake --build . --target install

popd

echo
echo "#### Setting the entitlements using ldid"
COMMAND_SET="codesign -f -s - --entitlements "$CLUTCH_ENTITLEMENTS" "${CLUTCH_BINARY}""
echo "${COMMAND_SET}"
eval "${COMMAND_SET}"

echo
echo "#### Dumping the entitlements using codesign"
COMMAND_CHK="${CODESIGN} -d --entitlements :- ${CLUTCH_BINARY}"
echo "${COMMAND_CHK}"
eval "${COMMAND_CHK}"



