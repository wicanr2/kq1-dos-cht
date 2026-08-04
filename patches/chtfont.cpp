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

#include "common/config-manager.h"
#include "graphics/fontman.h"
#include "common/ptr.h"
#include "common/file.h"
#include "common/fs.h"
#include "common/path.h"
#include "graphics/surface.h"

#include "gui/chtfont.h"

namespace GUI {

// File layout (all big-endian), produced by tools/build_eten_font.py:
//   "CHTG" | uint16 width | uint16 height | uint32 count
//   count * { uint32 code point, height * ceil(width/8) bytes of 1bpp bitmap, MSB left }
static const uint32 kChtFontMagic = MKTAG('C', 'H', 'T', 'G');
// A glyph box wider than this would mean a corrupt header rather than a font we
// want to render, and the per-glyph size is used to walk the file.
static const int kMaxGlyphDim = 64;

// Every live wrapper, so isWrapper() can answer without RTTI. Fonts live for the
// whole run and there are a handful of them, so a flat list is enough.
static Common::Array<const Graphics::Font *> s_wrappers;

ChtGuiFont::ChtGuiFont(const Graphics::Font *base, int w, int h)
	: _base(base), _w(w), _h(h) {
	s_wrappers.push_back(this);
}

// g_sysfont / g_sysfont_big / g_consolefont are static objects compiled into
// ScummVM, and FontManager::getFontByName() hands them straight back for the
// names the stock themes use ("clR6x12.bdf", "helvB12.bdf", "builtinConsole",
// "fixed5x8.bdf") without ever consulting its own map. So the font handed to
// us is one of those three far more often than not, and deleting it is exactly
// what FontManager's own destructor goes out of its way not to do.
static bool isBuiltinFont(const Graphics::Font *font) {
	return font && (font == FontMan.getFontByUsage(Graphics::FontManager::kGUIFont) ||
	                font == FontMan.getFontByUsage(Graphics::FontManager::kBigGUIFont) ||
	                font == FontMan.getFontByUsage(Graphics::FontManager::kConsoleFont));
}

ChtGuiFont::~ChtGuiFont() {
	for (uint i = 0; i < s_wrappers.size(); ++i) {
		if (s_wrappers[i] == this) {
			s_wrappers.remove_at(i);
			break;
		}
	}
	// Owning a font we must not free would turn every later GUI redraw into a
	// use-after-free, and the second free into a double free.
	if (!isBuiltinFont(_base))
		delete _base;
}

bool ChtGuiFont::isWrapper(const Graphics::Font *font) {
	if (!font)
		return false;
	for (uint i = 0; i < s_wrappers.size(); ++i) {
		if (s_wrappers[i] == font)
			return true;
	}
	return false;
}

// The GUI builds its fonts long before any engine starts, so the game's extra
// path is not on SearchMan yet: look there explicitly, otherwise the launcher
// would be the one place that still cannot draw the game's own name.
static Common::SeekableReadStream *openChtFont(const Common::Path &filename) {
	Common::File *f = new Common::File();
	if (f->open(filename))
		return f;
	delete f;

	if (!ConfMan.hasKey("extrapath"))
		return nullptr;
	const Common::Path extra(ConfMan.getPath("extrapath"));
	if (extra.empty())
		return nullptr;
	Common::FSNode node = Common::FSNode(extra).getChild(filename.toString());
	if (!node.exists())
		return nullptr;
	return node.createReadStream();
}

ChtGuiFont *ChtGuiFont::load(const Common::Path &filename, const Graphics::Font *base) {
	if (!base)
		return nullptr;

	Common::SeekableReadStream *stream = openChtFont(filename);
	if (!stream) {
		debug(1, "ChtGuiFont: '%s' not found on the search path or in extrapath",
		      filename.toString().c_str());
		return nullptr;
	}
	Common::ScopedPtr<Common::SeekableReadStream> f(stream);

	if (f->readUint32BE() != kChtFontMagic) {
		warning("ChtGuiFont: '%s' is not a CHTG font", filename.toString().c_str());
		return nullptr;
	}

	const int w = f->readUint16BE();
	const int h = f->readUint16BE();
	const uint32 count = f->readUint32BE();
	if (w <= 0 || h <= 0 || w > kMaxGlyphDim || h > kMaxGlyphDim || count == 0) {
		warning("ChtGuiFont: '%s' has an implausible header (%dx%d, %u glyphs)",
		        filename.toString().c_str(), w, h, count);
		return nullptr;
	}

	const uint32 bytesPerGlyph = h * ((w + 7) / 8);
	ChtGuiFont *font = new ChtGuiFont(base, w, h);
	font->_data.resize(count * bytesPerGlyph);

	for (uint32 i = 0; i < count; i++) {
		const uint32 code = f->readUint32BE();
		const uint32 offset = i * bytesPerGlyph;
		if (f->read(&font->_data[offset], bytesPerGlyph) != bytesPerGlyph) {
			warning("ChtGuiFont: '%s' ended after %u of %u glyphs", filename.toString().c_str(), i, count);
			break;
		}
		font->_index[code] = offset;
	}

	if (font->_index.empty()) {
		// Do not delete the wrapped font here: ownership only transfers on success.
		font->_base = nullptr;
		delete font;
		return nullptr;
	}

	debug(1, "ChtGuiFont: loaded %u glyphs (%dx%d) from '%s'",
	      (uint)font->_index.size(), w, h, filename.toString().c_str());
	return font;
}

int ChtGuiFont::getFontHeight() const {
	// Must cover the taller of the two fonts. Reporting only the wrapped font's
	// height looks like it keeps widget layout identical, but list rows are then
	// shorter than a Chinese glyph and the top of every character gets shaved off.
	return MAX(_base->getFontHeight(), _h);
}

int ChtGuiFont::getFontAscent() const {
	return _base->getFontAscent();
}

int ChtGuiFont::getMaxCharWidth() const {
	return MAX(_base->getMaxCharWidth(), _w);
}

int ChtGuiFont::getCharWidth(uint32 chr) const {
	if (hasGlyph(chr))
		return _w;
	return _base->getCharWidth(chr);
}

template<typename PixelType>
static void drawGlyphRow(byte *ptr, const byte *src, int xStart, int xEnd, uint32 color) {
	PixelType *dst = (PixelType *)ptr;
	for (int x = xStart; x <= xEnd; x++) {
		if (src[x >> 3] & (0x80 >> (x & 7)))
			dst[x - xStart] = (PixelType)color;
	}
}

void ChtGuiFont::drawChar(Graphics::Surface *dst, uint32 chr, int x, int y, uint32 color) const {
	if (!hasGlyph(chr)) {
		_base->drawChar(dst, chr, x, y, color);
		return;
	}

	assert(dst != nullptr);
	assert(dst->format.bytesPerPixel == 1 || dst->format.bytesPerPixel == 2 || dst->format.bytesPerPixel == 4);

	const int rowBytes = (_w + 7) / 8;
	const byte *src = &_data[_index[chr]];

	// Align on the top edge, like the wrapped font does: y is the top of the cell,
	// not the baseline. Offsetting by the ascent instead pushes the glyph above
	// the row and the clip below then eats its first few rows.
	int top = y;
	int height = _h;
	if (top < 0) {
		src -= top * rowBytes;
		height += top;
		top = 0;
	}
	if (top + height > dst->h)
		height = dst->h - top;
	if (height <= 0)
		return;

	int left = x;
	int width = _w;
	int xStart = 0;
	if (left < 0) {
		xStart = -left;
		width += left;
		left = 0;
	}
	if (left + width > dst->w)
		width = dst->w - left;
	if (width <= 0)
		return;
	const int xEnd = xStart + width - 1;

	byte *ptr = (byte *)dst->getBasePtr(left, top);
	for (int row = 0; row < height; row++, src += rowBytes, ptr += dst->pitch) {
		if (dst->format.bytesPerPixel == 1)
			drawGlyphRow<byte>(ptr, src, xStart, xEnd, color);
		else if (dst->format.bytesPerPixel == 2)
			drawGlyphRow<uint16>(ptr, src, xStart, xEnd, color);
		else
			drawGlyphRow<uint32>(ptr, src, xStart, xEnd, color);
	}
}

} // End of namespace GUI
