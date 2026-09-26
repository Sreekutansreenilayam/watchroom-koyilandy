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

      // 1. Assign Other Duties (Phone Duty, Control Room, Messenger)
      final allSfro = _getOnDutyPersonnel('SFRO');
      if (allSfro.isNotEmpty) {
         allSfro.sort((a, b) {
            if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
            return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
         });
         _phoneDutyIds = [allSfro.first.idNumber];
      }

      final allFro = _getOnDutyPersonnel('FRO');
      final froListForControlRoom = allFro.where((p) => !_phoneDutyIds.contains(p.idNumber) && !_sentryDutyIds.contains(p.idNumber)).toList();
      if (froListForControlRoom.isNotEmpty) {
         froListForControlRoom.sort((a, b) {
            if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
            return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
         });
         _controlRoomIds = [froListForControlRoom.first.idNumber];
      }

      final allKhg = _getOnDutyPersonnel('KHG');
      final khgListForMessenger = allKhg.where((p) => !_sentryDutyIds.contains(p.idNumber)).toList();
      if (khgListForMessenger.isNotEmpty) {
         khgListForMessenger.sort((a, b) {
            if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
            return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
         });
         _messengerIds = [khgListForMessenger.first.idNumber];
      }

      // 2. Fetch Available Personnel for Vehicles (excluding Other Duties)
      final List<Manpower> availableFROD = List.from(_getOnDutyPersonnel('FRO(D)'));
      final List<Manpower> availableKHG = _getOnDutyPersonnel('KHG').where((p) => 
         !_messengerIds.contains(p.idNumber) && 
         !_sentryDutyIds.contains(p.idNumber)
      ).toList();
      final List<Manpower> availableFRO = _getOnDutyPersonnel('FRO').where((p) => 
         !_phoneDutyIds.contains(p.idNumber) && 
         !_controlRoomIds.contains(p.idNumber) && 
         !_sentryDutyIds.contains(p.idNumber)
      ).toList();

      final dutyProvider = context.read<DutyProvider>();

      String pickForVehicle(List<Manpower> pool, String targetVehicleName) {
        if (pool.isEmpty) return '';
        
        pool.sort((a, b) {
          int scoreA = 0;
          int scoreB = 0;
          var aHist = _getLast3Duties(a.idNumber, _selectedDate, dutyProvider);
          var bHist = _getLast3Duties(b.idNumber, _selectedDate, dutyProvider);
          
          // +10 penalty if they were in this specific vehicle yesterday
          if (aHist.isNotEmpty && aHist[0].any((v) => v.contains(targetVehicleName))) scoreA += 10;
          if (bHist.isNotEmpty && bHist[0].any((v) => v.contains(targetVehicleName))) scoreB += 10;
          
          // +5 penalty if they were in it the day before
          if (aHist.length > 1 && aHist[1].any((v) => v.contains(targetVehicleName))) scoreA += 5;
          if (bHist.length > 1 && bHist[1].any((v) => v.contains(targetVehicleName))) scoreB += 5;
          
          if (scoreA != scoreB) return scoreA.compareTo(scoreB);
          
          // Fallback to overall historical count for this vehicle type if recent penalty is tied
          int freqA = 0;
          int freqB = 0;
          for (var reg in dutyProvider.registers) {
             for (var v in reg.vehicleAssignments) {
                 if (v.vehicleName.contains(targetVehicleName)) {
                     if (v.sfro.contains(a.idNumber) || v.fro.contains(a.idNumber) || v.khg.contains(a.idNumber) || v.froD.contains(a.idNumber)) freqA++;
                     if (v.sfro.contains(b.idNumber) || v.fro.contains(b.idNumber) || v.khg.contains(b.idNumber) || v.froD.contains(b.idNumber)) freqB++;
                 }
             }
          }
          if (freqA != freqB) return freqA.compareTo(freqB);
          
          // Tiebreaker: seniority
          return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
        });
        
        final best = pool.first;
        pool.removeAt(0);
        return best.idNumber;
      }

      String driver9874 = pickForVehicle(availableFROD, 'MTU KL01CU9874');
      String driver7112 = pickForVehicle(availableFROD, 'MTU KL01BZ7112');
      String driverMist = pickForVehicle(availableFROD, 'WATER MIST');
      String driverAmb = pickForVehicle(availableFROD, 'AMBULANCE');
      String driverMuv = pickForVehicle(availableFROD, 'MUV');
      String driverBullet = pickForVehicle(availableFROD, 'BULLET');
      
      // Fallback for driver shortage
      if (driver7112.isEmpty) driver7112 = driver9874;
      if (driverMist.isEmpty) driverMist = driver9874;
      if (driverAmb.isEmpty) driverAmb = driver9874;
      if (driverMuv.isEmpty) driverMuv = driver7112;
      if (driverBullet.isEmpty) driverBullet = driver9874;
      
      String driverJeep = driver9874;
      String driverMniMtu = driver7112;

      List<String> khgAmb = [];
      if (availableKHG.isNotEmpty) khgAmb.add(pickForVehicle(availableKHG, 'AMBULANCE'));
      if (availableKHG.isNotEmpty) khgAmb.add(pickForVehicle(availableKHG, 'AMBULANCE'));

      String khg9874 = pickForVehicle(availableKHG, 'MTU KL01CU9874');
      String khg7112 = pickForVehicle(availableKHG, 'MTU KL01BZ7112');
      String khgMist = pickForVehicle(availableKHG, 'WATER MIST');
      String khgMuv = pickForVehicle(availableKHG, 'MUV');
      String khgBullet = pickForVehicle(availableKHG, 'BULLET');

      // Fallback for KHG shortage (use Amb or 9874)
      if (khg9874.isEmpty) khg9874 = khgAmb.isNotEmpty ? khgAmb[0] : '';
      if (khg7112.isEmpty) khg7112 = khg9874;
      if (khgMist.isEmpty) khgMist = khg9874;
      if (khgMuv.isEmpty) khgMuv = khg7112;
      if (khgBullet.isEmpty) khgBullet = khg9874;

      List<String> fro9874 = [];
      List<String> fro7112 = [];
      List<String> froAmb = [];
      List<String> froMist = [];
      List<String> froMuv = [];
      
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) fro9874.add(pickForVehicle(availableFRO, 'MTU KL01CU9874')); }
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) fro7112.add(pickForVehicle(availableFRO, 'MTU KL01BZ7112')); }
      if (availableFRO.isNotEmpty) froAmb.add(pickForVehicle(availableFRO, 'AMBULANCE'));
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) froMist.add(pickForVehicle(availableFRO, 'WATER MIST')); }
      for (int i = 0; i < 3; i++) { if (availableFRO.isNotEmpty) froMuv.add(pickForVehicle(availableFRO, 'MUV')); }

      // Shortage Handlers
      void fillFromFallback(List<String> target, int requiredCount, List<String> fallbackPool) {
          for (var p in fallbackPool) {
              if (target.length >= requiredCount) break;
              if (!target.contains(p)) target.add(p);
          }
      }

      // Water Mist takes equally from 9874 and 7112 if shortage
      if (froMist.length < 2) {
          if (fro9874.isNotEmpty && !froMist.contains(fro9874[0])) froMist.add(fro9874[0]);
          if (fro7112.isNotEmpty && !froMist.contains(fro7112[0])) froMist.add(fro7112[0]);
      }
      
      // Other vehicles take from 9874, except MUV which takes from 7112
      fillFromFallback(froMuv, 3, fro7112);
      fillFromFallback(froAmb, 1, fro9874);
      fillFromFallback(fro7112, 3, fro9874);

      for (var v in _vehicles) {
        final vName = v.vehicleName;
        if (vName.contains('MTU KL01CU9874')) {
           _froDControllers[vName]?.text = driver9874;
           _khgControllers[vName]?.text = khg9874;
           _froControllers[vName]?.text = fro9874.join(', ');
        } else if (vName.contains('MTU KL01BZ7112')) {
           _froDControllers[vName]?.text = driver7112;
           _khgControllers[vName]?.text = khg7112;
           _froControllers[vName]?.text = fro7112.join(', ');
        } else if (vName.contains('WATER MIST KL01CC6015')) {
           _froDControllers[vName]?.text = driverMist;
           _khgControllers[vName]?.text = khgMist;
           _froControllers[vName]?.text = froMist.join(', ');
        } else if (vName.contains('AMBULANCE KL01CK792')) {
           _froDControllers[vName]?.text = driverAmb;
           _khgControllers[vName]?.text = khgAmb.join(', ');
           _froControllers[vName]?.text = froAmb.join(', ');
        } else if (vName.contains('MUV KL01DK2865')) {
           _froDControllers[vName]?.text = driverMuv;
           _khgControllers[vName]?.text = khgMuv;
           _froControllers[vName]?.text = froMuv.join(', ');
        } else if (vName.contains('BULLET KL01BB7142')) {
           _froDControllers[vName]?.text = driverBullet;
           _khgControllers[vName]?.text = khgBullet;
        } else if (vName.contains('JEEP KL01BB3717')) {
           _froDControllers[vName]?.text = driverJeep;
        } else if (vName.contains('MNI MTU KL01BB2997')) {
           _froDControllers[vName]?.text = driverMniMtu;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicles auto-assigned based on Koyilandy rules.'), backgroundColor: Colors.green),
      );
    });
  }
