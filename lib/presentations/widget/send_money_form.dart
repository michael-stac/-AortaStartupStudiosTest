import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/expection.dart';
import '../../domain/providers/payment_provider.dart';

class SendMoneyForm extends StatefulWidget {
  const SendMoneyForm({super.key});

  @override
  State<SendMoneyForm> createState() => _SendMoneyFormState();
}

class _SendMoneyFormState extends State<SendMoneyForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();

  /// Mock recipients for demo
  final List<Map<String, String>> recipients = [
    {'id': '1', 'name': 'Max Mustermann', 'email': 'max@example.com'},
    {'id': '2', 'name': 'Anna Schmidt', 'email': 'anna@example.com'},
    {'id': '3', 'name': 'Thomas Müller', 'email': 'thomas@example.com'},
    {'id': '4', 'name': 'Lisa Wagner', 'email': 'lisa@example.com'},
    {'id': '5', 'name': 'David Fischer', 'email': 'david@example.com'},
  ];

  String? _selectedRecipientId;

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send Money',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          /// Recipient Dropdown
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Recipient',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            value: _selectedRecipientId,
            items: recipients.map((recipient) {
              return DropdownMenuItem<String>(
                value: recipient['id'],
                child: Text(recipient['name']!),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRecipientId = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a recipient';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          /// Amount Input
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount (€)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.euro),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Please enter a valid amount';
              }
              if (amount > paymentProvider.effectiveBalance) {
                return 'Insufficient balance';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          /// Send Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: paymentProvider.isLoading
                  ? null
                  : () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    final recipient = recipients.firstWhere(
                          (r) => r['id'] == _selectedRecipientId,
                    );

                    await paymentProvider.sendMoney(
                      amount: double.parse(_amountController.text),
                      recipientId: recipient['id']!,
                      recipientName: recipient['name']!,
                    );

                    /// Show success snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Transaction queued successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    /// Clear form
                    _amountController.clear();
                    setState(() {
                      _selectedRecipientId = null;
                    });

                    /// Navigate back after delay
                    Future.delayed(const Duration(seconds: 1), () {
                      Navigator.pop(context);
                    });

                  } on InsufficientFundsException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: paymentProvider.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'Send Money',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}