import 'package:flutter/material.dart';

/// Design tokens mirroring Designing/spgas/styles.css (active brand: teal).
/// Any color/radius/spacing in the app MUST come from here — never hardcode.
class DT {
  DT._();

  // ---- Brand (teal) ----
  static const brand50 = Color(0xFFF0FDFA);
  static const brand100 = Color(0xFFCCFBF1);
  static const brand200 = Color(0xFF99F6E4);
  static const brand500 = Color(0xFF14B8A6);
  static const brand600 = Color(0xFF0D9488);
  static const brand700 = Color(0xFF0F766E);
  static const brand800 = Color(0xFF115E59);
  static const brand900 = Color(0xFF134E4A);

  // ---- Semantic ----
  static const ok50 = Color(0xFFECFDF5);
  static const ok100 = Color(0xFFD1FAE5);
  static const ok500 = Color(0xFF10B981);
  static const ok600 = Color(0xFF059669);
  static const ok700 = Color(0xFF047857);

  static const warn50 = Color(0xFFFFFBEB);
  static const warn100 = Color(0xFFFEF3C7);
  static const warn500 = Color(0xFFF59E0B);
  static const warn600 = Color(0xFFD97706);
  static const warn700 = Color(0xFFB45309);

  static const err50 = Color(0xFFFEF2F2);
  static const err100 = Color(0xFFFEE2E2);
  static const err500 = Color(0xFFEF4444);
  static const err600 = Color(0xFFDC2626);
  static const err700 = Color(0xFFB91C1C);

  static const info500 = Color(0xFF0891B2);
  static const info600 = Color(0xFF0E7490);

  // ---- Neutrals ----
  static const bg = Color(0xFFF7F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF1F3F8);
  static const surface3 = Color(0xFFE9ECF3);
  static const border = Color(0xFFE4E7EE);
  static const borderStrong = Color(0xFFD1D5DC);
  static const divider = Color(0xFFECEFF5);
  static const text = Color(0xFF0F172A);
  static const text2 = Color(0xFF475569);
  static const text3 = Color(0xFF94A3B8);

  // ---- Radii ----
  static const rXs = 4.0;
  static const rSm = 6.0;
  static const rMd = 10.0;
  static const rLg = 12.0;
  static const rXl = 16.0;

  // ---- Spacing (8px base) ----
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  // ---- Layout ----
  static const sidebarWidth = 240.0;
  static const sidebarCollapsedWidth = 64.0;
  static const topbarHeight = 56.0;
  static const statusbarHeight = 32.0;
  static const rowHeight = 44.0;
  static const inputHeight = 36.0;
  static const btnHeight = 36.0;

  // ---- Typography scale ----
  static const fsH1 = 24.0;
  static const fsH2 = 18.0;
  static const fsBody = 14.0;
  static const fsSm = 12.0;
  static const fsNum = 28.0;

  // ---- Elevation (matches --sh-sm/md/lg) ----
  static const shSm = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const shMd = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const shLg = [
    BoxShadow(color: Color(0x260F172A), blurRadius: 25, offset: Offset(0, 10)),
  ];
}
