import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GoongLocation {
  final String address;
  final double lat;
  final double lng;

  GoongLocation({required this.address, required this.lat, required this.lng});
}

class GoongAddressSearch extends StatefulWidget {
  final String label;
  final String hint;
  final Function(GoongLocation?) onSelected;
  final String apiKey;

  const GoongAddressSearch({
    super.key,
    required this.label,
    required this.hint,
    required this.onSelected,
    this.apiKey = 'E8tXU5PV0Sm19d0dX1mJqwb40t6MjLNrRCiiF8LC',
  });

  @override
  State<GoongAddressSearch> createState() => _GoongAddressSearchState();
}

class _GoongAddressSearchState extends State<GoongAddressSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<dynamic> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        if (mounted) {
          setState(() {
            _suggestions = [];
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = [];
        });
      }
      widget.onSelected(null);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final url = Uri.parse('https://rsapi.goong.io/Place/AutoComplete?api_key=${widget.apiKey}&input=${Uri.encodeComponent(query)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          if (mounted) {
            setState(() {
              _suggestions = data['predictions'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectPlace(dynamic place) async {
    _focusNode.unfocus();

    if (mounted) {
      setState(() {
        _suggestions = [];
      });
    }

    final address = place['description'];
    _controller.text = address;

    try {
      final url = Uri.parse('https://rsapi.goong.io/Place/Detail?place_id=${place['place_id']}&api_key=${widget.apiKey}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final geometry = data['result']['geometry']['location'];
          final location = GoongLocation(
            address: address,
            lat: geometry['lat'],
            lng: geometry['lng'],
          );
          widget.onSelected(location);
        }
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _fetchSuggestions,
          decoration: InputDecoration(
            hintText: widget.hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: _isLoading
                ? const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
                : const Icon(Icons.location_on, color: Colors.grey, size: 20),
          ),
        ),
        if (_suggestions.isNotEmpty && _focusNode.hasFocus)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.grey),
                  title: Text(place['description'], style: const TextStyle(fontSize: 14)),
                  onTap: () => _selectPlace(place),
                );
              },
            ),
          ),
      ],
    );
  }
}
