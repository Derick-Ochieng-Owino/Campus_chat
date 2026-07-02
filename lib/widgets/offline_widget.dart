import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';

class InternetConnectionWidget extends StatefulWidget {
  final Widget child;

  const InternetConnectionWidget({Key? key, required this.child}) : super(key: key);

  @override
  _InternetConnectionWidgetState createState() => _InternetConnectionWidgetState();
}

class _InternetConnectionWidgetState extends State<InternetConnectionWidget> {
  bool _isOnline = true;
  bool _isChecking = false; // Tracks retry button loading state
  late final Connectivity _connectivity;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _checkStatus();

    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isOnline = !results.contains(ConnectivityResult.none);
      });
    });
  }

  // Extracted logic so it can be called by initState and the Retry Button
  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);

    // Artificial slight delay to give feedback to the user that it's checking
    await Future.delayed(const Duration(milliseconds: 600));

    final results = await _connectivity.checkConnectivity();
    setState(() {
      _isOnline = !results.contains(ConnectivityResult.none);
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/offline.lottie',
                  width: 250,
                  height: 250,
                  repeat: true,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Connection Lost",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please check your internet settings and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Retry Button
                ElevatedButton(
                  onPressed: _isChecking ? null : _checkStatus,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text("Try Again", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}