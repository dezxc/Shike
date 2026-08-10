#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_PATH="${PROJECT_DIR}/build/Shike.app"
DIST_DIR="${PROJECT_DIR}/dist"

cd "${PROJECT_DIR}"
make all

VERSION="$(plutil -extract CFBundleShortVersionString raw "${APP_PATH}/Contents/Info.plist")"
ARCHIVE_PATH="${DIST_DIR}/Shike-${VERSION}-macOS.zip"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"
DMG_PATH="${DIST_DIR}/Shike-${VERSION}-macOS.dmg"
DMG_CHECKSUM_PATH="${DMG_PATH}.sha256"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:--}"
DMG_STAGE=""

cleanup() {
    if [[ -n "${DMG_STAGE}" && -d "${DMG_STAGE}" ]]; then
        rm -rf "${DMG_STAGE}"
    fi
}
trap cleanup EXIT

mkdir -p "${DIST_DIR}"

create_archive() {
    rm -f "${ARCHIVE_PATH}"
    ditto --norsrc --noextattr -c -k --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"
}

create_dmg() {
    cleanup
    DMG_STAGE="$(mktemp -d "${DIST_DIR}/.dmg-stage.XXXXXX")"
    ditto --norsrc --noextattr "${APP_PATH}" "${DMG_STAGE}/Shike.app"
    ln -s /Applications "${DMG_STAGE}/Applications"
    rm -f "${DMG_PATH}"
    hdiutil create -quiet -volname "拾刻 Shike" -srcfolder "${DMG_STAGE}" -format UDZO "${DMG_PATH}"
    cleanup
    DMG_STAGE=""
}

if [[ "${SIGN_IDENTITY}" != "-" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_PATH}"
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
fi

create_archive

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    if [[ "${SIGN_IDENTITY}" == "-" ]]; then
        print -u2 "NOTARY_PROFILE 已设置，但缺少 DEVELOPER_ID_APPLICATION。"
        exit 2
    fi
    xcrun notarytool submit "${ARCHIVE_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
    xcrun stapler staple "${APP_PATH}"
    xcrun stapler validate "${APP_PATH}"
    create_archive
fi

create_dmg
if [[ "${SIGN_IDENTITY}" != "-" ]]; then
    codesign --force --timestamp --sign "${SIGN_IDENTITY}" "${DMG_PATH}"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
fi

shasum -a 256 "${ARCHIVE_PATH}" > "${CHECKSUM_PATH}"
shasum -a 256 "${DMG_PATH}" > "${DMG_CHECKSUM_PATH}"

print "ZIP 发布包：${ARCHIVE_PATH}"
print "DMG 安装盘：${DMG_PATH}"
print "校验值：${CHECKSUM_PATH}"
print "校验值：${DMG_CHECKSUM_PATH}"
if [[ "${SIGN_IDENTITY}" == "-" ]]; then
    print "注意：当前为临时签名测试包；公开分发前请配置 Developer ID 与 Apple 公证。"
fi
