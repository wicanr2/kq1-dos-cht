/* ScummVM - Graphic Adventure Engine
 *
 * ScummVM is the legal property of its developers, whose names
 * are too numerous to list here. Please refer to the COPYRIGHT
 * file distributed with this source distribution.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "common/file.h"
#include "graphics/big5.h"

#include "sci/sci.h"
#include "sci/graphics/screen.h"
#include "sci/graphics/fontchinese.h"

namespace Sci {

// Big5 font data file shipped alongside the game (part of the CHT patch).
static const char *kChineseFontFile = "kq1_big5.fnt";
// Layout advance per Chinese char (logical 320x200 px).
// Low-res advance (menu path): the ETEN low-res glyph is 16px wide and drawBig5Char clips to
// this width, so anything narrower shaves strokes off the right edge of menu titles.
static const int kBig5Width = 16;
// Upper bound of what Big5Font::drawBig5Char() may write into a scratch buffer. Size scratch
// buffers by these, never by kBig5Width: the low-res path can be handed a 16px destination
// pitch, and a kBig5Width-sized buffer would then overflow (arm64 -fstack-protector-strong
// aborts at the first draw; on Linux the same overflow runs silently). Upstream's
// kChineseTraditionalMaxHeight is private, hence the local copy.
static const int kBig5GlyphMaxW = Graphics::Big5Font::kChineseTraditionalWidth;  // 16
static const int kBig5GlyphMaxH = 16;

// Advance and line height in script pixels once the CHT 640x400 upscale is on (screen.cpp).
// The glyph is drawn at its native 16x15 pixels straight onto the display buffer, and two
// display pixels are one script pixel, so it occupies 8x8 script cells — the very cell the
// game's own 8px English font uses. That is the whole point of the upscale: nothing the game
// sized for English (status bar, window title bar, dialogue boxes, dropdown rows) has to be
// heightened to fit Chinese, so nothing of the picture has to be given up for it.
static const int kBig5WidthHi = 8;
static const int kBig5HeightHi = 8;

GfxFontChinese::GfxFontChinese(ResourceManager *resMan, GfxScreen *screen, GuiResourceId resourceId)
	: _screen(screen), _resourceId(resourceId), _big5(nullptr), _big5Height(15) {
	// Original SCI font for single-byte (ASCII / control) glyphs.
	_asciiFont = new GfxFontFromResource(resMan, screen, resourceId);

	Common::File fontFile;
	if (fontFile.open(kChineseFontFile)) {
		_big5 = new Graphics::Big5Font();
		_big5->loadPrefixedRaw(fontFile, _big5Height);
		// Clamp: the glyph scratch buffer in draw() is sized for kBig5GlyphMaxH rows, and a
		// font file claiming more would overflow it.
		_big5Height = MIN<int>(_big5->getFontHeight(), kBig5GlyphMaxH);
	} else {
		warning("GfxFontChinese: could not open '%s'; Chinese glyphs will be blank", kChineseFontFile);
	}

}

GfxFontChinese::~GfxFontChinese() {
	delete _big5;
	delete _asciiFont;
}

GuiResourceId GfxFontChinese::getResourceId() {
	return _resourceId;
}

bool GfxFontChinese::useHiRes() const {
	return _screen->getDisplayWidth() > _screen->getWidth();
}

byte GfxFontChinese::getHeight() {
	byte asciiHeight = _asciiFont->getHeight();
	// Line height is the taller of the two fonts, or dropdown rows overlap. On the upscaled
	// display the Chinese glyph is 8 script rows, i.e. the same as the English font, so the
	// line height ends up identical to the English one.
	return MAX<byte>(asciiHeight, (byte)(useHiRes() ? kBig5HeightHi : _big5Height));
}

// text16 tests this on the first (lead) byte before combining the pair.
bool GfxFontChinese::isDoubleByte(uint16 chr) {
	return (chr >= 0x81) && (chr <= 0xFE);
}

byte GfxFontChinese::getCharWidth(uint16 chr) {
	// chr may arrive either as a bare lead byte (during width scans) or as a
	// combined lead|(trail<<8) value (during drawing). Both mean a Big5 char.
	// The advance must match what draw() actually paints, or line-wrapping (GetLongest) and
	// rendering disagree and text overflows its box.
	if (chr > 0xFF || isDoubleByte(chr))
		return useHiRes() ? kBig5WidthHi : kBig5Width;
	return _asciiFont->getCharWidth(chr);
}

byte GfxFontChinese::getCharHeight(uint16 chr) {
	if (chr > 0xFF || isDoubleByte(chr))
		return (byte)(useHiRes() ? kBig5HeightHi : _big5Height);
	return _asciiFont->getHeight();
}

void GfxFontChinese::draw(uint16 chr, int16 top, int16 left, byte color, bool greyedOutput) {
	// Single-byte: delegate to the original SCI font (keeps ASCII pixel-identical).
	//
	// 但要往下對齊。SCI 傳進來的 top 是「這一行的頂端」，中文 15 列、原字型只有 8-9 列，
	// 兩邊都從頂端畫的話 ASCII 會浮在中文上方 6 列，像上標一樣（F1 說明視窗裡的
	// ESC／Tab／Ctrl-C、狀態列的分數數字都看得出來）。差額補在上面，兩者底線就齊了。
	// 走 hi-res 時中文只有 8 列、與原字型同高，差額為 0，這段自動不動作。
	if (chr <= 0xFF) {
		const int16 asciiHeight = _asciiFont->getHeight();
		const int16 chineseHeight = useHiRes() ? kBig5HeightHi : _big5Height;
		const int16 baselineFix = (chineseHeight > asciiHeight) ? (chineseHeight - asciiHeight) : 0;
		_asciiFont->draw(chr, top + baselineFix, left, color, greyedOutput);
		return;
	}

	// Double-byte: chr == lead | (trail << 8); Big5Font wants (lead << 8) | trail.
	uint16 point = ((chr & 0xFF) << 8) | (chr >> 8);

	if (useHiRes()) {
		if (drawHiRes(point, top, left, color))
			return;
		// Missing glyph: fall through to the placeholder below.
		_asciiFont->draw('?', top, left, color, greyedOutput);
		return;
	}

	byte glyph[kBig5GlyphMaxW * kBig5GlyphMaxH];
	memset(glyph, 0, sizeof(glyph));
	bool drawn = false;
	if (_big5)
		drawn = _big5->drawBig5Char(glyph, point, kBig5Width, _big5Height, kBig5Width,
		                            /*color*/ 1, /*outlineColor*/ 0, /*outline*/ false, /*bpp*/ 1);
	if (!drawn) {
		// Fall back to a placeholder so missing glyphs are visible, not silent.
		_asciiFont->draw('?', top, left, color, greyedOutput);
		return;
	}

	uint16 screenWidth = _screen->fontIsUpscaled() ? _screen->getDisplayWidth() : _screen->getWidth();
	uint16 screenHeight = _screen->fontIsUpscaled() ? _screen->getDisplayHeight() : _screen->getHeight();

	for (int y = 0; y < _big5Height; y++) {
		for (int x = 0; x < kBig5Width; x++) {
			if (!glyph[y * kBig5Width + x])
				continue;
			int screenX = left + x;
			int screenY = top + y;
			if (0 <= screenX && screenX < screenWidth && 0 <= screenY && screenY < screenHeight)
				_screen->putFontPixel(top, screenX, y, color);
		}
	}
}

// Draw the ETEN glyph at its native size straight onto the 640x400 display buffer.
//
// Nothing is written to the visual plane — there is no room for 16x15 detail in an 8x8 script
// cell. The consequence to keep in mind: anything that repaints the visual plane over this
// area (fillRect, invertRect, a picture) also repaints the display and takes the glyph with
// it. Windows are safe because bitsSave/bitsRestore carry the display buffer too
// (GfxScreen::bitsSaveDisplayScreen). The menu highlight is not, and is handled separately
// (GfxScreen::chtInvertDisplayRect).
bool GfxFontChinese::drawHiRes(uint16 point, int16 top, int16 left, byte color) {
	byte glyph[kBig5GlyphMaxW * kBig5GlyphMaxH];
	memset(glyph, 0, sizeof(glyph));
	if (!_big5 || !_big5->drawBig5Char(glyph, point, kBig5GlyphMaxW, _big5Height, kBig5GlyphMaxW,
	                                   /*color*/ 1, /*outlineColor*/ 0, /*outline*/ false, /*bpp*/ 1))
		return false;

	// Centre the 15-row glyph in the 16 display rows the 8-row script cell covers.
	const int dispLeft = left * 2;
	const int dispTop = top * 2 + (kBig5HeightHi * 2 - _big5Height) / 2;
	const int dispW = _screen->getDisplayWidth();
	const int dispH = _screen->getDisplayHeight();

	for (int gy = 0; gy < _big5Height; gy++) {
		const int y = dispTop + gy;
		if (y < 0 || y >= dispH)
			continue;
		for (int gx = 0; gx < kBig5GlyphMaxW; gx++) {
			if (!glyph[gy * kBig5GlyphMaxW + gx])
				continue;
			const int x = dispLeft + gx;
			if (x >= 0 && x < dispW)
				_screen->putPixelOnDisplay(x, y, color);
		}
	}
	return true;
}

} // End of namespace Sci
