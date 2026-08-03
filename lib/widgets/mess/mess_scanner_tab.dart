import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/mess_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/mess_service.dart';

class MessScannerTab extends StatefulWidget {
  final bool isActive;
  const MessScannerTab({super.key, this.isActive = false});

  @override
  State<MessScannerTab> createState() => _MessScannerTabState();
}

class _MessScannerTabState extends State<MessScannerTab>
    with WidgetsBindingObserver {
  final MessService _messService = MessService();
  // autoStart: false — camera only starts when the tab is actually active
  final MobileScannerController _scannerController =
      MobileScannerController(autoStart: false);
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) _scannerController.start();
  }

  @override
  void didUpdateWidget(MessScannerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _scannerController.start();
      } else {
        _scannerController.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;
    if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _scannerController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  void _onQrScanned(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final String? rawCode = capture.barcodes.firstOrNull?.rawValue;
    if (rawCode == null || rawCode.isEmpty) return;

    setState(() {
      _isProcessingScan = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scannerUser = authProvider.userProfile;

    final result = await _messService.verifyAndRecordMealScan(
      qrPayload: rawCode,
      scannerId: scannerUser?.uid ?? 'SCANNER_APP',
      scannerName: scannerUser?.name ?? 'Mess Manager',
    );

    if (!mounted) return;

    _showScanResultModal(result);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessingScan = false;
        });
      }
    });
  }

  void _showScanResultModal(MessScanValidationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            result.isGranted ? Colors.white : const Color(0xFFFEF2F2),
        title: Column(
          children: [
            Icon(
              result.isGranted
                  ? Icons.check_circle_outline_rounded
                  : Icons.highlight_off_rounded,
              size: 56,
              color: result.isGranted
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
            const SizedBox(height: 12),
            Text(
              result.isGranted ? 'ACCESS GRANTED' : 'ACCESS DENIED',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: result.isGranted
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.message,
              style: TextStyle(
                fontSize: 13,
                color: result.isGranted
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: result.isGranted
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text(
                  'OK / Ready Next Scan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeMeal = MessTimings.getCurrentMeal(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3A8A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE MEAL SCANNER',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeMeal != null
                          ? activeMeal.displayName
                          : 'Mess Closed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeMeal != null
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    activeMeal != null ? 'OPEN' : 'CLOSED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onQrScanned,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Point camera at Student Dynamic QR code for instant entry validation.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
