import 'package:flutter/material.dart';
import 'khata_page.dart';


/// InvoicesPage has been fully replaced by KhataPage for dedicated Udhar & Pending Payment management.
class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});


  static void refreshInvoices() {
    KhataPage.refreshKhata();
  }


  @override
  Widget build(BuildContext context) {
    return const KhataPage();
  }
}
