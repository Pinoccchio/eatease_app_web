import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'restaurant_data_manager.dart';

class ReservationScreen extends StatefulWidget {
  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RestaurantDataManager _restaurantDataManager = RestaurantDataManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<DocumentSnapshot>> _getReservations(String status) {
    final userId = _auth.currentUser!.uid;
    return _firestore
        .collectionGroup('reservations')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status)
        .orderBy('reservationDateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Widget _buildReservationCard(DocumentSnapshot reservation) {
    final data = reservation.data() as Map<String, dynamic>;
    final restaurantName = data['restaurantName'] ?? 'Unknown Restaurant';
    final logoUrl = data['logoUrl'] ?? 'https://via.placeholder.com/80';
    final dateTime = (data['reservationDateTime'] as Timestamp).toDate();
    final totalPrice = (data['totalPrice'] as num).toDouble();
    final status = data['status'] ?? 'pending';
    final reservationId = reservation.id;
    final restaurantId = reservation.reference.parent.parent!.id;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReservationDetailsScreen(
              reservationId: reservationId,
              restaurantId: restaurantId,
            ),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  logoUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'lib/assets/app_images/placeholder.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy - h:mm a').format(dateTime),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PHP ${totalPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == 'completed' || status == 'approved')
                Icon(Icons.check_circle, color: Colors.green, size: 28)
              else if (status == 'cancelled')
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: 28),
                  onPressed: () => _confirmDelete(restaurantId, reservationId),
                )
              else if (status == 'pending')
                  IconButton(
                    icon: Icon(Icons.cancel_outlined, color: Colors.deepOrange, size: 28),
                    onPressed: () => _showCancelDialog(context, restaurantId, reservationId),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String restaurantId, String reservationId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Deletion',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete this reservation?',
                  style: GoogleFonts.poppins(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _deleteReservation(restaurantId, reservationId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteReservation(String restaurantId, String reservationId) async {
    try {
      await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('reservations')
          .doc(reservationId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reservation deleted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting reservation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Reservations',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepOrange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepOrange,
          labelStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: 'Completed'),
            Tab(text: 'Pending'),
            Tab(text: 'Cancelled'),
            Tab(text: 'Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReservationList('completed'),
          _buildReservationList('pending'),
          _buildReservationList('cancelled'),
          _buildReservationList('approved'),
        ],
      ),
    );
  }

  Widget _buildReservationList(String status) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _getReservations(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No $status reservations',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
            ),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _buildReservationCard(snapshot.data![index]);
          },
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context, String restaurantId, String reservationId) {
    String? selectedReason;
    TextEditingController otherReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cancel Booking',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Select a reason for cancellation',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        hint: Text('Choose a reason'),
                        isExpanded: true,
                        items: [
                          'Change of plans',
                          'Restaurant issues',
                          'Not needed anymore',
                          'Other',
                        ].map((reason) {
                          return DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedReason = newValue;
                          });
                        },
                      ),
                      if (selectedReason == 'Other')
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextField(
                            controller: otherReasonController,
                            decoration: InputDecoration(
                              labelText: 'Specify Reason',
                              hintText: 'Enter reason',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              String finalReason = selectedReason == 'Other'
                                  ? otherReasonController.text
                                  : selectedReason ?? '';
                              await _restaurantDataManager.cancelReservation(
                                restaurantId,
                                reservationId,
                                finalReason,
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reservation cancelled successfully.')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error cancelling reservation: $e')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel Reservation',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ReservationDetailsScreen extends StatelessWidget {
  final String reservationId;
  final String restaurantId;

  ReservationDetailsScreen({required this.reservationId, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reservation Details'),
        backgroundColor: Colors.deepOrange,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('reservations')
            .doc(reservationId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Reservation not found'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final restaurantName = data['restaurantName'] ?? 'Unknown Restaurant';
          final dateTime = (data['reservationDateTime'] as Timestamp).toDate();
          final totalPrice = (data['totalPrice'] as num).toDouble();
          final status = data['status'] ?? 'pending';
          final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          final orderNotes = data['orderNotes'] as String? ?? 'No notes provided';
          final cancellationReason = data['cancellationReason'] as String? ?? 'Not specified';

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurantName,
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Date: ${DateFormat('MMM d, yyyy - h:mm a').format(dateTime)}',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                Text(
                  'Status: ${status.toUpperCase()}',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (status == 'cancelled')
                  Text(
                    'Cancellation Reason: $cancellationReason',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.red),
                  ),
                Text(
                  'Total: PHP ${totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                ),
                SizedBox(height: 16),
                Text(
                  'Ordered Items:',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ...items.map((item) => ListTile(
                  title: Text(item['name'], style: GoogleFonts.poppins(fontSize: 16)),
                  subtitle: Text('Quantity: ${item['quantity']}', style: GoogleFonts.poppins(fontSize: 14)),
                  trailing: Text(
                    'PHP ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                )),
                SizedBox(height: 16),
                Text(
                  'Order Notes:',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  orderNotes,
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}