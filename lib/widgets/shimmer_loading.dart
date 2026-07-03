import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _animation.value, 0),
              end: Alignment(-_animation.value, 0),
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}

class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big balance card
          ShimmerLoading(width: double.infinity, height: 140, borderRadius: 16),
          const SizedBox(height: 12),
          // Two mini cards
          Row(
            children: [
              Expanded(child: ShimmerLoading(width: double.infinity, height: 100, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: ShimmerLoading(width: double.infinity, height: 100, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 16),
          // Two stat cards
          Row(
            children: [
              Expanded(child: ShimmerLoading(width: double.infinity, height: 80, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: ShimmerLoading(width: double.infinity, height: 80, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 16),
          // Title placeholder
          ShimmerLoading(width: 160, height: 20, borderRadius: 4),
          const SizedBox(height: 12),
          // List items
          ShimmerLoading(width: double.infinity, height: 56, borderRadius: 12),
          const SizedBox(height: 8),
          ShimmerLoading(width: double.infinity, height: 56, borderRadius: 12),
          const SizedBox(height: 8),
          ShimmerLoading(width: double.infinity, height: 56, borderRadius: 12),
        ],
      ),
    );
  }
}

class ShimmerMovimientosList extends StatelessWidget {
  const ShimmerMovimientosList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ShimmerLoading(width: double.infinity, height: 64, borderRadius: 16),
        );
      },
    );
  }
}
