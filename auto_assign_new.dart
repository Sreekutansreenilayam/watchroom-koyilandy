
  void _autoAssignVehicles() {
    if (!AppConfig.isKoyilandy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto Assign is currently optimized only for Koyilandy.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      for (var v in _vehicles) {
        _sfroControllers[v.vehicleName]?.clear();
        _froControllers[v.vehicleName]?.clear();
        _khgControllers[v.vehicleName]?.clear();
        _froDControllers[v.vehicleName]?.clear();
      }

      // Fetch All Available Personnel
      final allSfro = List<Manpower>.from(_getOnDutyPersonnel('SFRO'));
      final allFro = List<Manpower>.from(_getOnDutyPersonnel('FRO'));
      final allKhg = List<Manpower>.from(_getOnDutyPersonnel('KHG'));
      final allFroD = List<Manpower>.from(_getOnDutyPersonnel('FRO(D)'));

      final dutyProvider = context.read<DutyProvider>();
      Map<String, int> assignmentsToday = {};

      String pickForDuty(List<Manpower> pool, String dutyTypeOrVehicle) {
        if (pool.isEmpty) return '';
        List<Manpower> sortedPool = List.from(pool);
        sortedPool.sort((a, b) {
          int assignA = assignmentsToday[a.idNumber] ?? 0;
          int assignB = assignmentsToday[b.idNumber] ?? 0;
          if (assignA != assignB) return assignA.compareTo(assignB);
          
          int scoreA = 0;
          int scoreB = 0;
          var aHist = _getLast3Duties(a.idNumber, _selectedDate, dutyProvider);
          var bHist = _getLast3Duties(b.idNumber, _selectedDate, dutyProvider);
          
          // History penalty
          bool isOtherDuty = dutyTypeOrVehicle == 'Phone Duty' || dutyTypeOrVehicle == 'Watch Room/Wireless' || dutyTypeOrVehicle == 'Messenger';
          
          bool hasDuty(List<String> d, String target) {
             if (isOtherDuty) return d.any((x) => x.contains(target));
             return d.any((x) => x.contains(target)); // They are mixed in history
          }
          
          if (aHist.isNotEmpty && hasDuty(aHist[0], dutyTypeOrVehicle)) scoreA += 10;
          if (bHist.isNotEmpty && hasDuty(bHist[0], dutyTypeOrVehicle)) scoreB += 10;
          if (aHist.length > 1 && hasDuty(aHist[1], dutyTypeOrVehicle)) scoreA += 5;
          if (bHist.length > 1 && hasDuty(bHist[1], dutyTypeOrVehicle)) scoreB += 5;
          
          if (scoreA != scoreB) return scoreA.compareTo(scoreB);
          
          int freqA = 0;
          int freqB = 0;
          for (var reg in dutyProvider.registers) {
             if (isOtherDuty) {
                if (dutyTypeOrVehicle == 'Phone Duty' && reg.phoneDuty.contains(a.idNumber)) freqA++;
                if (dutyTypeOrVehicle == 'Watch Room/Wireless' && reg.controlRoom.contains(a.idNumber)) freqA++;
                if (dutyTypeOrVehicle == 'Messenger' && reg.messenger.contains(a.idNumber)) freqA++;
                
                if (dutyTypeOrVehicle == 'Phone Duty' && reg.phoneDuty.contains(b.idNumber)) freqB++;
                if (dutyTypeOrVehicle == 'Watch Room/Wireless' && reg.controlRoom.contains(b.idNumber)) freqB++;
                if (dutyTypeOrVehicle == 'Messenger' && reg.messenger.contains(b.idNumber)) freqB++;
             } else {
                for (var v in reg.vehicleAssignments) {
                    if (v.vehicleName.contains(dutyTypeOrVehicle)) {
                        if (v.sfro.contains(a.idNumber) || v.fro.contains(a.idNumber) || v.khg.contains(a.idNumber) || v.froD.contains(a.idNumber)) freqA++;
                        if (v.sfro.contains(b.idNumber) || v.fro.contains(b.idNumber) || v.khg.contains(b.idNumber) || v.froD.contains(b.idNumber)) freqB++;
                    }
                }
             }
          }
          if (freqA != freqB) return freqA.compareTo(freqB);
          
          return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
        });
        
        final best = sortedPool.first;
        assignmentsToday[best.idNumber] = (assignmentsToday[best.idNumber] ?? 0) + 1;
        pool.removeWhere((p) => p.idNumber == best.idNumber);
        return best.idNumber;
      }

      _phoneDutyIds.clear();
      _controlRoomIds.clear();
      _messengerIds.clear();

      // --- ASSIGN OTHER DUTIES (Phone, Watch Room, Messenger) ---
      // We assign these first, and remove them from the pools so they don't get vehicles!
      final sfroPoolForPhone = allSfro.where((p) => !_sentryDutyIds.contains(p.idNumber)).toList();
      if (sfroPoolForPhone.isNotEmpty) {
         String picked = pickForDuty(sfroPoolForPhone, 'Phone Duty');
         if (picked.isNotEmpty) _phoneDutyIds = [picked];
      }

      final froPoolForWatchRoom = allFro.where((p) => !_sentryDutyIds.contains(p.idNumber) && !_phoneDutyIds.contains(p.idNumber)).toList();
      if (froPoolForWatchRoom.isNotEmpty) {
         String picked = pickForDuty(froPoolForWatchRoom, 'Watch Room/Wireless'); // This maps to controlRoom in DB
         if (picked.isNotEmpty) _controlRoomIds = [picked];
      }

      final khgPoolForMessenger = allKhg.where((p) => !_sentryDutyIds.contains(p.idNumber)).toList();
      if (khgPoolForMessenger.isNotEmpty) {
         String picked = pickForDuty(khgPoolForMessenger, 'Messenger');
         if (picked.isNotEmpty) _messengerIds = [picked];
      }

      // --- AVAILABLE POOLS FOR VEHICLES ---
      final availableSFRO = allSfro.where((p) => !_sentryDutyIds.contains(p.idNumber) && !_phoneDutyIds.contains(p.idNumber)).toList();
      final availableFRO = allFro.where((p) => !_sentryDutyIds.contains(p.idNumber) && !_phoneDutyIds.contains(p.idNumber) && !_controlRoomIds.contains(p.idNumber)).toList();
      final availableKHG = allKhg.where((p) => !_sentryDutyIds.contains(p.idNumber) && !_messengerIds.contains(p.idNumber)).toList();
      final availableFROD = allFroD.where((p) => !_sentryDutyIds.contains(p.idNumber)).toList();

      // --- FRO(D) ASSIGNMENT ---
      String driver9874 = pickForDuty(availableFROD, 'MTU KL01CU9874');
      String driver7112 = pickForDuty(availableFROD, 'MTU KL01BZ7112');
      
      String driverMist = pickForDuty(availableFROD, 'WATER MIST');
      String driverAmb = pickForDuty(availableFROD, 'AMBULANCE');
      String driverMuv = pickForDuty(availableFROD, 'MUV');
      String driverBullet = pickForDuty(availableFROD, 'BULLET');
      
      if (driver7112.isEmpty) driver7112 = driver9874;
      if (driverMist.isEmpty) driverMist = driver9874;
      if (driverAmb.isEmpty) driverAmb = driver9874;
      if (driverMuv.isEmpty) driverMuv = driver7112;
      if (driverBullet.isEmpty) driverBullet = driver9874;
      
      String driverJeep = driver9874;
      String driverMniMtu = driver7112;

      // --- KHG ASSIGNMENT ---
      String khg9874 = pickForDuty(availableKHG, 'MTU KL01CU9874');
      String khg7112 = pickForDuty(availableKHG, 'MTU KL01BZ7112');
      
      String khgMist = pickForDuty(availableKHG, 'WATER MIST');
      String khgMuv = pickForDuty(availableKHG, 'MUV');
      String khgBullet = pickForDuty(availableKHG, 'BULLET');
      
      List<String> khgAmb = [];
      if (availableKHG.isNotEmpty) khgAmb.add(pickForDuty(availableKHG, 'AMBULANCE'));
      if (availableKHG.isNotEmpty) khgAmb.add(pickForDuty(availableKHG, 'AMBULANCE'));

      if (khg9874.isEmpty) khg9874 = khgAmb.isNotEmpty ? khgAmb[0] : '';
      if (khg7112.isEmpty) khg7112 = khg9874;
      if (khgMist.isEmpty) khgMist = khg9874;
      if (khgMuv.isEmpty) khgMuv = khg7112;
      if (khgBullet.isEmpty) khgBullet = khg9874;
      if (khgAmb.isEmpty) khgAmb.add(khg9874);

      // --- FRO ASSIGNMENT ---
      List<String> fro9874 = [];
      List<String> fro7112 = [];
      List<String> froMist = [];
      List<String> froMuv = [];
      List<String> froAmb = [];
      
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) fro9874.add(pickForDuty(availableFRO, 'MTU KL01CU9874')); }
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) fro7112.add(pickForDuty(availableFRO, 'MTU KL01BZ7112')); }
      
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) froMist.add(pickForDuty(availableFRO, 'WATER MIST')); }
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) froMuv.add(pickForDuty(availableFRO, 'MUV')); }
      if (availableFRO.isNotEmpty) froAmb.add(pickForDuty(availableFRO, 'AMBULANCE'));

      void fillFromFallback(List<String> target, int requiredCount, List<String> fallbackPool) {
          for (var p in fallbackPool) {
              if (target.length >= requiredCount) break;
              if (!target.contains(p)) target.add(p);
          }
      }

      if (froMist.length < 2) {
          if (fro9874.isNotEmpty && !froMist.contains(fro9874[0])) froMist.add(fro9874[0]);
          if (fro7112.isNotEmpty && !froMist.contains(fro7112[0])) froMist.add(fro7112[0]);
      }
      fillFromFallback(froMuv, 3, fro7112);
      fillFromFallback(froAmb, 1, fro9874);
      fillFromFallback(fro7112, 3, fro9874);

      // --- SFRO ASSIGNMENT ---
      Map<String, String> sfroAssignments = {};
      if (availableSFRO.length == 1) {
         String sfroId = availableSFRO.first.idNumber;
         sfroAssignments['MTU KL01CU9874'] = sfroId;
         sfroAssignments['MUV KL01DK2865'] = sfroId;
         sfroAssignments['MTU KL01BZ7112'] = sfroId;
      } else if (availableSFRO.length > 1) {
         sfroAssignments['MTU KL01CU9874'] = pickForDuty(availableSFRO, 'MTU KL01CU9874');
         sfroAssignments['MUV KL01DK2865'] = pickForDuty(availableSFRO, 'MUV KL01DK2865');
         sfroAssignments['MTU KL01BZ7112'] = pickForDuty(availableSFRO, 'MTU KL01BZ7112');
         
         if (availableSFRO.length > 3) {
             sfroAssignments['MNI MTU KL01BB2997'] = pickForDuty(availableSFRO, 'MNI MTU KL01BB2997');
             sfroAssignments['WATER MIST KL01CC6015'] = pickForDuty(availableSFRO, 'WATER MIST KL01CC6015');
         }
      }

      // Write to controllers
      for (var v in _vehicles) {
        final vName = v.vehicleName;
        if (vName.contains('MTU KL01CU9874')) {
           _froDControllers[vName]?.text = driver9874;
           _khgControllers[vName]?.text = khg9874;
           _froControllers[vName]?.text = fro9874.toSet().join(', ');
           if (sfroAssignments.containsKey('MTU KL01CU9874')) _sfroControllers[vName]?.text = sfroAssignments['MTU KL01CU9874']!;
        } else if (vName.contains('MTU KL01BZ7112')) {
           _froDControllers[vName]?.text = driver7112;
           _khgControllers[vName]?.text = khg7112;
           _froControllers[vName]?.text = fro7112.toSet().join(', ');
           if (sfroAssignments.containsKey('MTU KL01BZ7112')) _sfroControllers[vName]?.text = sfroAssignments['MTU KL01BZ7112']!;
        } else if (vName.contains('WATER MIST KL01CC6015')) {
           _froDControllers[vName]?.text = driverMist;
           _khgControllers[vName]?.text = khgMist;
           _froControllers[vName]?.text = froMist.toSet().join(', ');
           if (sfroAssignments.containsKey('WATER MIST KL01CC6015')) _sfroControllers[vName]?.text = sfroAssignments['WATER MIST KL01CC6015']!;
        } else if (vName.contains('AMBULANCE KL01CK792')) {
           _froDControllers[vName]?.text = driverAmb;
           _khgControllers[vName]?.text = khgAmb.toSet().join(', ');
           _froControllers[vName]?.text = froAmb.toSet().join(', ');
        } else if (vName.contains('MUV KL01DK2865')) {
           _froDControllers[vName]?.text = driverMuv;
           _khgControllers[vName]?.text = khgMuv;
           _froControllers[vName]?.text = froMuv.toSet().join(', ');
           if (sfroAssignments.containsKey('MUV KL01DK2865')) _sfroControllers[vName]?.text = sfroAssignments['MUV KL01DK2865']!;
        } else if (vName.contains('BULLET KL01BB7142')) {
           _froDControllers[vName]?.text = driverBullet;
           _khgControllers[vName]?.text = khgBullet;
        } else if (vName.contains('JEEP KL01BB3717')) {
           _froDControllers[vName]?.text = driverJeep;
        } else if (vName.contains('MNI MTU KL01BB2997')) {
           _froDControllers[vName]?.text = driverMniMtu;
           if (sfroAssignments.containsKey('MNI MTU KL01BB2997')) _sfroControllers[vName]?.text = sfroAssignments['MNI MTU KL01BB2997']!;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Smart AI Vehicles & Duties Auto-assigned.'), backgroundColor: Colors.green),
      );
    });
  }
