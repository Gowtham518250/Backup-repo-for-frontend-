import 'dart:math';
import 'package:flutter/material.dart';

class GeometricRegistrationPage extends StatefulWidget {
  const GeometricRegistrationPage({super.key});

  @override
  State<GeometricRegistrationPage> createState() => _GeometricRegistrationPageState();
}

class _GeometricRegistrationPageState extends State<GeometricRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String _shapeType = 'Triangle';

  static const List<String> _shapeOptions = [
    'Triangle',
    'Square',
    'Circle',
    'Hexagon',
  ];

  static const List<Map<String, String>> _examples = [
    {
      'title': 'Triangle Hall Sign',
      'subtitle': 'Register a sharp geometric brand mark for in-store display.',
    },
    {
      'title': 'Circle Loyalty Badge',
      'subtitle': 'Create a circular loyalty token for customer rewards.',
    },
    {
      'title': 'Hexagon Product Tag',
      'subtitle': 'Register a polygonal packaging label layout example.',
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _submitRegistration() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Geometric registration created successfully.'),
      ),
    );

    _nameController.clear();
    _detailsController.clear();
    setState(() {
      _shapeType = 'Triangle';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geometric Registration'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GeoBackgroundPainter(),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Design + Register',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use geometric registration examples to create a structured pattern asset or ID.',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                _buildExamplesSection(),
                const SizedBox(height: 24),
                _buildFormSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamplesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registration Examples',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._examples.map((example) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  leading: const Icon(Icons.auto_awesome_rounded, color: Colors.indigo),
                  title: Text(example['title']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(example['subtitle']!),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        _shapeType = example['title']!.contains('Circle')
                            ? 'Circle'
                            : example['title']!.contains('Hexagon')
                                ? 'Hexagon'
                                : 'Triangle';
                        _nameController.text = example['title']!;
                        _detailsController.text = example['subtitle']!;
                      });
                    },
                    child: const Text('Use'),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFormSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Geometric Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _shapeType,
                decoration: const InputDecoration(labelText: 'Shape type'),
                items: _shapeOptions
                    .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _shapeType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Registration name'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(labelText: 'Details'),
                maxLines: 3,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter details' : null,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Register asset'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Current shape: $_shapeType',
                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeoBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.shade50
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = Colors.indigo.withValues(alpha: 0.14)
      ..strokeWidth = 1.2;

    const int lines = 8;
    for (int i = 0; i < lines; i++) {
      final y = size.height * (i / (lines - 1));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final shapePaint = Paint()
      ..color = Colors.indigo.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width * 0.7, size.height * 0.2);
    final radius = 72.0;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(center, radius + i * 16, shapePaint);
    }

    final polygonPaint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path();
    final int sides = 6;
    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi * i / sides) - pi / 2;
      final point = center + Offset(cos(angle), sin(angle)) * 48;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, polygonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
