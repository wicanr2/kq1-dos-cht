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

#ifndef GUI_CHTFONT_H
#define GUI_CHTFONT_H

#include "common/array.h"
#include "common/hashmap.h"
#include "common/path.h"
#include "common/str.h"
#include "graphics/font.h"

namespace GUI {

/**
 * Wraps a GUI font so that Chinese characters render from a bitmap font.
 *
 * The stock GUI fonts carry no CJK glyphs, so a game whose name is written in
 * Chinese shows up in the launcher as a row of empty boxes. This wrapper keeps
 * every single-byte character on the original font (so English GUI text stays
 * pixel-identical) and draws anything above U+007F from an ETEN bitmap font
 * shipped with the translation data.
 *
 * The font file (kq1_gui.fnt, produced by tools/build_eten_font.py --prefix kq1)
 * is indexed by Unicode code point rather than Big5, because the GUI works in
 * Common::U32String and drawChar() receives code points: keeping the mapping in
 * the data file avoids needing a Unicode->Big5 conversion at runtime, which is
 * not guaranteed to be available (iconv/ICU are optional).
 *
 * Layout is deliberately left to the wrapped font: getFontHeight() reports the
 * original height so widget metrics do not shift, and a taller glyph is clipped
 * rather than allowed to push the line apart.
 */
class ChtGuiFont : public Graphics::Font {
public:
	/**
	 * Load the CHT bitmap font and wrap @p base with it.
	 *
	 * Takes ownership of @p base. Returns nullptr when the font file is absent
	 * or malformed, in which case the caller keeps using @p base unchanged.
	 */
	static ChtGuiFont *load(const Common::Path &filename, const Graphics::Font *base);

	/**
	 * Is @p font one of our wrappers?
	 *
	 * ThemeEngine hands a font back out of FontMan's cache on the second and any
	 * later request for the same name, so a wrapper installed earlier comes back
	 * around. It must not be wrapped a second time (both wrappers would then own
	 * and delete the same base font) nor cast to BdfFont* the way the caller does
	 * with a freshly loaded font. RTTI is off in ScummVM, hence the registry.
	 */
	static bool isWrapper(const Graphics::Font *font);

	~ChtGuiFont() override;

	int getFontHeight() const override;
	int getFontAscent() const override;
	int getMaxCharWidth() const override;
	int getCharWidth(uint32 chr) const override;
	void drawChar(Graphics::Surface *dst, uint32 chr, int x, int y, uint32 color) const override;

private:
	ChtGuiFont(const Graphics::Font *base, int w, int h);

	bool hasGlyph(uint32 chr) const { return _index.contains(chr); }

	const Graphics::Font *_base;
	Common::HashMap<uint32, uint32> _index;   // code point -> offset into _data
	Common::Array<byte> _data;
	int _w, _h;
};

} // End of namespace GUI

#endif
