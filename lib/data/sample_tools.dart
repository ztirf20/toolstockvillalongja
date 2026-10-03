class SampleTool {
  final String name;
  final String category;
  final String sku;
  final String unit;
  final double price;
  final int quantity;
  final int minStock;
  final String supplier;

  const SampleTool(this.name, this.category, this.sku, this.unit, this.price,
      this.quantity, this.minStock, this.supplier);
}

const _hw = 'Davao Hardware Supply';
const _tools = 'Mindanao Tools Trading';
const _build = 'Metro Building Supply';
const _elec = 'BrightLine Electrical';
const _plumb = 'AquaFlow Plumbing';
const _paint = 'ColorMax Paints';
const _safe = 'SafeWorks Trading';

const List<SampleTool> kSampleTools = [
  // Hand Tools
  SampleTool('Claw Hammer 16oz', 'Hand Tools', 'HT-001', 'pcs', 250, 24, 5, _hw),
  SampleTool('Screwdriver Set 6pc', 'Hand Tools', 'HT-002', 'set', 320, 15, 4, _hw),
  SampleTool('Adjustable Wrench 10in', 'Hand Tools', 'HT-003', 'pcs', 380, 12, 4, _hw),
  SampleTool('Combination Pliers 8in', 'Hand Tools', 'HT-004', 'pcs', 210, 3, 5, _hw),
  SampleTool('Hand Saw 20in', 'Hand Tools', 'HT-005', 'pcs', 290, 10, 3, _hw),
  SampleTool('Tape Measure 5m', 'Hand Tools', 'HT-006', 'pcs', 120, 30, 8, _hw),
  SampleTool('Spirit Level 24in', 'Hand Tools', 'HT-007', 'pcs', 340, 0, 3, _hw),
  // Power Tools
  SampleTool('Cordless Drill 18V', 'Power Tools', 'PT-001', 'pcs', 3200, 6, 2, _tools),
  SampleTool('Angle Grinder 4in', 'Power Tools', 'PT-002', 'pcs', 2650, 4, 2, _tools),
  SampleTool('Circular Saw 7-1/4in', 'Power Tools', 'PT-003', 'pcs', 3900, 2, 2, _tools),
  SampleTool('Jigsaw 650W', 'Power Tools', 'PT-004', 'pcs', 2400, 5, 2, _tools),
  SampleTool('Electric Sander', 'Power Tools', 'PT-005', 'pcs', 2100, 7, 2, _tools),
  // Fasteners
  SampleTool('Common Wire Nails 2in', 'Fasteners', 'FS-001', 'kg', 95, 120, 40, _hw),
  SampleTool('Concrete Nails 3in', 'Fasteners', 'FS-002', 'kg', 110, 60, 20, _hw),
  SampleTool('Wood Screws 1.5in', 'Fasteners', 'FS-003', 'box', 180, 35, 10, _hw),
  SampleTool('Machine Bolts M10', 'Fasteners', 'FS-004', 'pack', 240, 18, 6, _hw),
  SampleTool('Expansion Anchors 8mm', 'Fasteners', 'FS-005', 'pack', 150, 4, 8, _hw),
  // Building Materials
  SampleTool('Portland Cement 40kg', 'Building Materials', 'BM-001', 'bag', 270, 80, 25, _build),
  SampleTool('Plywood 1/2in 4x8', 'Building Materials', 'BM-002', 'pcs', 780, 22, 8, _build),
  SampleTool('Steel Bar 10mm x 6m', 'Building Materials', 'BM-003', 'pcs', 235, 150, 40, _build),
  SampleTool('Hollow Blocks 4in', 'Building Materials', 'BM-004', 'pcs', 14, 500, 150, _build),
  SampleTool('GI Wire #16', 'Building Materials', 'BM-005', 'roll', 420, 9, 4, _build),
  // Electrical
  SampleTool('Electrical Tape', 'Electrical', 'EL-001', 'roll', 35, 60, 20, _elec),
  SampleTool('THHN Wire 2.0mm x 75m', 'Electrical', 'EL-002', 'roll', 1850, 8, 3, _elec),
  SampleTool('Circuit Breaker 20A', 'Electrical', 'EL-003', 'pcs', 295, 14, 5, _elec),
  SampleTool('LED Bulb 9W', 'Electrical', 'EL-004', 'pcs', 85, 2, 20, _elec),
  SampleTool('Extension Cord 5m', 'Electrical', 'EL-005', 'pcs', 450, 11, 4, _elec),
  // Plumbing
  SampleTool('PVC Pipe 1/2in x 3m', 'Plumbing', 'PL-001', 'pcs', 85, 70, 20, _plumb),
  SampleTool('PVC Elbow 1/2in', 'Plumbing', 'PL-002', 'pcs', 12, 150, 50, _plumb),
  SampleTool('Teflon Tape', 'Plumbing', 'PL-003', 'roll', 25, 90, 30, _plumb),
  SampleTool('Gate Valve 1/2in', 'Plumbing', 'PL-004', 'pcs', 220, 0, 5, _plumb),
  SampleTool('Chrome Faucet', 'Plumbing', 'PL-005', 'pcs', 380, 9, 3, _plumb),
  // Paint & Supplies
  SampleTool('Latex Paint White 4L', 'Paint & Supplies', 'PS-001', 'pcs', 780, 20, 6, _paint),
  SampleTool('Paint Brush 3in', 'Paint & Supplies', 'PS-002', 'pcs', 95, 40, 10, _paint),
  SampleTool('Paint Roller Set', 'Paint & Supplies', 'PS-003', 'set', 210, 16, 5, _paint),
  SampleTool('Sandpaper #120', 'Paint & Supplies', 'PS-004', 'pcs', 15, 5, 25, _paint),
  SampleTool('Masking Tape 1in', 'Paint & Supplies', 'PS-005', 'roll', 38, 45, 15, _paint),
  // Safety Gear
  SampleTool('Safety Helmet', 'Safety Gear', 'SG-001', 'pcs', 220, 25, 8, _safe),
  SampleTool('Work Gloves', 'Safety Gear', 'SG-002', 'pair', 95, 40, 12, _safe),
  SampleTool('Safety Goggles', 'Safety Gear', 'SG-003', 'pcs', 140, 18, 6, _safe),
  SampleTool('Dust Mask (box of 50)', 'Safety Gear', 'SG-004', 'box', 260, 3, 5, _safe),
  SampleTool('Safety Boots', 'Safety Gear', 'SG-005', 'pair', 1250, 8, 3, _safe),
];