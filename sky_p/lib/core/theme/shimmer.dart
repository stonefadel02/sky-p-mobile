import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class HomeShimmerPlaceholder extends StatelessWidget {
  const HomeShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Fake Carrousel
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 30),
            // Fake ServiceGrid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: List.generate(4, (index) => Column(
                  children: [
                    CircleAvatar(radius: 25, backgroundColor: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 40, color: Colors.white),
                  ],
                )),
              ),
            ),
            const SizedBox(height: 30),
            // Fake LastOperations
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: List.generate(3, (index) => Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}