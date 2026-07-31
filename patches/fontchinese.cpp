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
// Status-bar advance: the compact path draws the 16-px-wide low-res glyph 1:1 into the display
// buffer, so one character occupies exactly 8 logical columns — packed, and short enough that
// the score/title line still fits across 320 columns.
static const int kBig5WidthCompact = 8;
// Upper bound of what Big5Font::drawBig5Char() may write into a scratch buffer. Size scratch
// buffers by these, never by kBig5Width: the low-res path can be handed a 16px destination
// pitch, and a kBig5Width-sized buffer would then overflow (arm64 -fstack-protector-strong
// aborts at the first draw; on Linux the same overflow runs silently). Upstream's
// kChineseTraditionalMaxHeight is private, hence the local copy.
static const int kBig5GlyphMaxW = Graphics::Big5Font::kChineseTraditionalWidth;  // 16
static const int kBig5GlyphMaxH = 16;

// No hi-res path here: KQ4/LSL2 draw a second 24x24 Big5 font straight onto a 640x400 display
// buffer, but that needs the forced ZH_TWN upscale, which KQ1's permanent status bar does not
// survive (see the CHT note in screen.cpp). Without the upscale getDisplayWidth() equals
// getWidth(), so such a path could never trigger — KQ1 renders every Chinese glyph through the
// native 16x15 ETEN font below.

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

byte GfxFontChinese::getHeight() {
	byte asciiHeight = _asciiFont->getHeight();
	// Every Chinese glyph draws at its native 15 rows, so the line height is simply the taller
	// of the two fonts. Dropdown items overlap if this reports less than _big5Height.
	return MAX<byte>(asciiHeight, (byte)_big5Height);
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
	if (chr > 0xFF || isDoubleByte(chr)) {
		if (_screen->compactTextActive())
			return kBig5WidthCompact;
		return kBig5Width;
	}
	return _asciiFont->getCharWidth(chr);
}

byte GfxFontChinese::getCharHeight(uint16 chr) {
	if (chr > 0xFF || isDoubleByte(chr))
		return (byte)_big5Height;
	return _asciiFont->getHeight();
}

void GfxFontChinese::draw(uint16 chr, int16 top, int16 left, byte color, bool greyedOutput) {
	// Single-byte: delegate to the original SCI font (keeps ASCII pixel-identical).
	if (chr <= 0xFF) {
		_asciiFont->draw(chr, top, left, color, greyedOutput);
		return;
	}

	// Double-byte: chr == lead | (trail << 8); Big5Font wants (lead << 8) | trail.
	uint16 point = ((chr & 0xFF) << 8) | (chr >> 8);

	// Compact path: only reachable on an upscaled display, where the status bar's fixed height
	// (10 script rows) would otherwise force the glyph through a 2x scale it has no room for.
	// KQ1 runs unscaled, so this is inert today and the normal path below does the drawing;
	// it stays for the same reason the compact advance does — see kBig5WidthCompact.
	if (_screen->compactTextActive() && _screen->getDisplayWidth() > _screen->getWidth()) {
		if (drawCompact(point, top, left, color))
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

// Draw the 16x15 low-res Big5 glyph at 1:1 into the display buffer, so it keeps its own pixel
// size instead of being 2x-upscaled. Used for the fixed-height status bar. Returns false when
// the glyph is unavailable so the caller can fall back.
bool GfxFontChinese::drawCompact(uint16 point, int16 top, int16 left, byte color) {
	if (!_big5)
		return false;
	byte glyph[kBig5GlyphMaxW * kBig5GlyphMaxH];
	memset(glyph, 0, sizeof(glyph));
	const int gw = Graphics::Big5Font::kChineseTraditionalWidth;
	if (!_big5->drawBig5Char(glyph, point, gw, _big5Height, gw,
	                         /*color*/ 1, /*outlineColor*/ 0, /*outline*/ false, /*bpp*/ 1))
		return false;

	const int dispLeft = left * 2;
	const int dispTop = top * 2;
	const int dispW = _screen->getDisplayWidth();
	const int dispH = _screen->getDisplayHeight();

	const bool savedUpscaled = _screen->fontIsUpscaled();
	_screen->setFontIsUpscaled(true);
	for (int gy = 0; gy < _big5Height; gy++) {
		if (dispTop + gy < 0 || dispTop + gy >= dispH)
			continue;
		for (int gx = 0; gx < gw; gx++) {
			if (!glyph[gy * gw + gx])
				continue;
			const int dispX = dispLeft + gx;
			if (dispX < 0 || dispX >= dispW)
				continue;
			_screen->putFontPixel(dispTop, dispX, gy, color);
		}
	}
	_screen->setFontIsUpscaled(savedUpscaled);
	return true;
}

} // End of namespace Sci
