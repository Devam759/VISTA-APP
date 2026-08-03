import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../models/mess_model.dart';
import '../common/vista_loader.dart';

class MessPdfViewerDialog extends StatefulWidget {
  final MessWeeklyPdf weeklyPdf;

  const MessPdfViewerDialog({super.key, required this.weeklyPdf});

  static void show(BuildContext context, MessWeeklyPdf weeklyPdf) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => MessPdfViewerDialog(weeklyPdf: weeklyPdf),
    );
  }

  @override
  State<MessPdfViewerDialog> createState() => _MessPdfViewerDialogState();
}

class _MessPdfViewerDialogState extends State<MessPdfViewerDialog> {
  final PdfViewerController _controller = PdfViewerController();
  bool _isFullscreen = false;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _errorMessage;

  @override
  void dispose() {
    super.dispose();
  }

  void _zoomIn() {
    _controller.zoomUp();
  }

  void _zoomOut() {
    _controller.zoomDown();
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      _controller.goToPage(pageNumber: _currentPage + 1);
    }
  }

  void _prevPage() {
    if (_currentPage > 1) {
      _controller.goToPage(pageNumber: _currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E3A8A),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close Menu',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.weeklyPdf.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Version ${widget.weeklyPdf.version} • PDF Document',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Page Counter Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Page $_currentPage of $_totalPages',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                    tooltip: 'Toggle Fullscreen',
                    onPressed: () {
                      setState(() {
                        _isFullscreen = !_isFullscreen;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Main PDF Content
            Expanded(
              child: Stack(
                children: [
                  if (_errorMessage != null)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() => _errorMessage = null),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else
                    PdfViewer.uri(
                      Uri.parse(widget.weeklyPdf.pdfUrl),
                      controller: _controller,
                      params: PdfViewerParams(
                        maxScale: 4.0,
                        minScale: 0.5,
                        onPageChanged: (page) {
                          if (page != null) {
                            setState(() {
                              _currentPage = page;
                            });
                          }
                        },
                        onViewerReady: (document, controller) {
                          setState(() {
                            _totalPages = document.pages.length;
                          });
                        },
                        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
                          return const Center(
                            child: VistaClassicLoader(
                              message: 'Loading Weekly Menu PDF...',
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBannerBuilder: (context, error, stackTrace, documentRef) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf_outlined, size: 56, color: Colors.orangeAccent),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Unable to load Weekly Menu PDF',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    error.toString(),
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Bottom Floating Action Controls
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.navigate_before, color: Colors.white),
                              onPressed: _currentPage > 1 ? _prevPage : null,
                              tooltip: 'Previous Page',
                            ),
                            IconButton(
                              icon: const Icon(Icons.zoom_out, color: Colors.white),
                              onPressed: _zoomOut,
                              tooltip: 'Zoom Out',
                            ),
                            IconButton(
                              icon: const Icon(Icons.zoom_in, color: Colors.white),
                              onPressed: _zoomIn,
                              tooltip: 'Zoom In',
                            ),
                            IconButton(
                              icon: const Icon(Icons.navigate_next, color: Colors.white),
                              onPressed: _currentPage < _totalPages ? _nextPage : null,
                              tooltip: 'Next Page',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
