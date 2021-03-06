//
//  BYBOptoStimmerManager.m
//  OptoStimmer
//
//  Created by Greg Gage on 4/14/13.
//  Copyright (c) 2013 Backyard Brains. All rights reserved.
//

#import "BYBOptoStimmerManager.h"

@implementation BYBOptoStimmerManager

// delegate bookkeeping
id <BYBOptoStimmerManagerDelegate> delegate;
- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    delegate = newDelegate;
}

- (id)init
{
    if ((self = [super init]))
    {
        self.CM = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

-(int) searchForOptoStimmeres:(int) timeout{

    NSLog(@"searchForOptoStimmeres() - Entered");
    maximumSignalStrength = -10000;
    if (self.CM.state  != CBCentralManagerStatePoweredOn) {
        NSLog(@"searchForOptoStimmeres() - CoreBluetooth not correctly initialized !\r\n");
        NSLog(@"searchForOptoStimmeres() - State = %d (%s)\r\n",self.CM.state,[self centralManagerStateToString:self.CM.state]);
        [[self delegate] didSearchForOptoStimmeres:@[]];
        [[self delegate] hadBluetoothError: self.CM.state];
        return -1;
    }
    
    
    //UInt16 s = [self swap:BYB_BATTERY_SERVICE_UUID];
    //NSData *sd = [[NSData alloc] initWithBytes:(char *)&s length:2];
    //CBUUID *su = [CBUUID UUIDWithData:sd];
    //serviceUUIDs - An array of CBUUID objects that the app is interested in. In this case, each CBUUID object represents the UUID of a service that a peripheral is advertising.
    
    // Start scanning
    //[self.CM scanForPeripheralsWithServices:@[su] options:0];
    [self.CM scanForPeripheralsWithServices:nil options:NULL];
    
    NSLog(@"searchForOptoStimmeres() - Scanning...");
    [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];  //Set a timer to Turn Off
    
    return 0;
}


-(int) connectToOptoStimmer:(BYBOptoStimmer *) optoStimmer{
    self.activeOptoStimmer = optoStimmer;
    [self connectPeripheral:self.activeOptoStimmer.peripheral];
    
    
    //[self getAllServicesFromOptoStimmer:self.activeOptoStimmer.peripheral];
    return 0;
}

-(int) disconnectFromOptoStimmer{
    
    [self.CM cancelPeripheralConnection:self.activeOptoStimmer.peripheral];
    self.activeOptoStimmer = nil;
    
    return 0;
}

-(void) sendMoveCommandToActiveOptoStimmer: (BYBMovementCommand) command{
    switch (command) {
            char c  = 0x01;
        case moveLeft:
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_STIM_LEFT_UUID data:[NSData dataWithBytes: &c length: sizeof(c)]];
            break;
        case moveRight:
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_STIM_RIGHT_UUID data:[NSData dataWithBytes: &c length: sizeof(c)]];
            break;
            
        default:
            break;
    }
}


//
// Units are converted for sending it over BT so that it fits in one byte per parameter
//
// One unit of frequency equals 0.5Hz
// one unit of pulse width equals (100/255)% of period of impuls
// one unit of duration equals 8ms
//
-(void) sendUpdatedSettingsToActiveOptoStimmer {
    
    UInt8 data;
    
    //Units are converted for sending it over BT so that it fits in one byte per parameter
    
    
    if([self.activeOptoStimmer.firmwareVersion isEqualToString:@"0.81"] || [self.activeOptoStimmer.firmwareVersion isEqualToString:@"0.8"])
    {
    
            //One unit of frequency equals 0.5Hz
            if(self.activeOptoStimmer.frequency.floatValue<1.0f)
            {
                data = (UInt8)roundf((self.activeOptoStimmer.frequency.floatValue*2.0f));
            }
            else
            {
                data = (UInt8)roundf((self.activeOptoStimmer.frequency.intValue*2.0f));
            }
            if(data<1)
            {
                data  = 1;
            }
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_FREQUENCY_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];

            //one unit of pulse width equals (100/255)% of period of impuls
           // data = (int)(255.0 * (self.activeOptoStimmer.pulseWidth.floatValue/(1000.0/self.activeOptoStimmer.frequency.floatValue)));
            data = (UInt8)(self.activeOptoStimmer.pulseWidth.unsignedIntValue & 0xFF);
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_PULSEWIDTH_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];

            //one unit of duration equals 8ms
            data = self.activeOptoStimmer.duration.integerValue/8; //Note we need to divide by 8ms.
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_DURATION_IN_5MS_INTERVALS_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
            
            data = self.activeOptoStimmer.randomMode.integerValue;
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_RANDOMMODE_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
            
            data = self.activeOptoStimmer.gain.unsignedIntegerValue;
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_GAIN_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
            
            
            uint pulseWidthTemp = self.activeOptoStimmer.pulseWidth.unsignedIntValue;
            data = (UInt8)((pulseWidthTemp >> 8) & 0xFF);
            [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_PULSE_WIDTH_SEC_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
    }
    else if([self.activeOptoStimmer.firmwareVersion isEqualToString:@"1.0"])
    {
        //One unit of frequency equals 0.5Hz

        data = (UInt8)self.activeOptoStimmer.frequency.intValue;
        
        if(data<1)
        {
            data  = 1;
        }
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_FREQUENCY_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        

        data = (UInt8)(self.activeOptoStimmer.pulseWidth.unsignedIntValue);
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_PULSEWIDTH_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        //one unit of duration equals 8ms
        data = self.activeOptoStimmer.duration.unsignedIntValue/5; //Note we need to divide by 8ms.
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_DURATION_IN_5MS_INTERVALS_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        data = self.activeOptoStimmer.randomMode.integerValue;
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_RANDOMMODE_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        data = self.activeOptoStimmer.gain.unsignedIntegerValue;
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_GAIN_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
    }
    else
    {
        //do latest conversions. Unrecognized firmware.
        
        
        
        
        
        
        //One unit of frequency equals 0.5Hz
        if(self.activeOptoStimmer.frequency.floatValue<1.0f)
        {
            data = (UInt8)roundf((self.activeOptoStimmer.frequency.floatValue*2.0f));
        }
        else
        {
            data = (UInt8)roundf((self.activeOptoStimmer.frequency.intValue*2.0f));
        }
        if(data<1)
        {
            data  = 1;
        }
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_FREQUENCY_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        //one unit of pulse width equals (100/255)% of period of impuls
        // data = (int)(255.0 * (self.activeOptoStimmer.pulseWidth.floatValue/(1000.0/self.activeOptoStimmer.frequency.floatValue)));
        data = (UInt8)(self.activeOptoStimmer.pulseWidth.unsignedIntValue & 0xFF);
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_PULSEWIDTH_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        //one unit of duration equals 8ms
        data = self.activeOptoStimmer.duration.integerValue/8; //Note we need to divide by 8ms.
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_DURATION_IN_5MS_INTERVALS_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        data = self.activeOptoStimmer.randomMode.integerValue;
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_RANDOMMODE_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        data = self.activeOptoStimmer.gain.unsignedIntegerValue;
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_GAIN_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        
        uint pulseWidthTemp = self.activeOptoStimmer.pulseWidth.unsignedIntValue;
        data = (UInt8)((pulseWidthTemp >> 8) & 0xFF);
        [self writeValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_PULSE_WIDTH_SEC_UUID data:[NSData dataWithBytes: &data length: sizeof(data)]];
        
        
        
        
        
        
        
    }

}

-(void) getAllServicesFromOptoStimmer:(CBPeripheral *)p{
    NSLog(@"Entering getAllServicesFromOptoStimmer");
    [p discoverServices:nil]; // Discover all services without filter
}

-(void) getAllCharacteristicsFromOptoStimmer:(CBPeripheral *)p{
    NSLog(@"Entering getAllCharacteristicsFromOptoStimmer");
    
    for (int i=0; i < p.services.count; i++) {
        CBService *s = [p.services objectAtIndex:i];
        NSLog(@"Fetching characteristics for service with UUID : %s",[self CBUUIDToString:s.UUID]);
        [p discoverCharacteristics:nil forService:s];
    }
}


- (void) connectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Entering connectPeripheral(UUID : %s)",[self UUIDToString:peripheral.identifier]);
    
    self.activeOptoStimmer.peripheral = peripheral;
    self.activeOptoStimmer.peripheral.delegate = self;
    [self.CM connectPeripheral:self.activeOptoStimmer.peripheral options:nil];
    
}

- (void) scanTimer:(NSTimer *)timer {
    [self.CM stopScan];
    NSLog(@"[local] Stopped Scanning");
    NSLog(@"[local] Known peripherals : %d",[self->_peripherals count]);
    
    [self printKnownPeripherals];
    if ([_peripherals count] > 0 ){
        BYBOptoStimmer * r = [[BYBOptoStimmer alloc] init];
        r.peripheral = _peripherals[0];
        [[self delegate] didSearchForOptoStimmeres:@[r]];
    }
    else{
        [[self delegate] didSearchForOptoStimmeres:@[]];
    }
    
}


-(void) readValue: (int)serviceUUID characteristicUUID:(int)characteristicUUID {
    UInt16 s = [self swap:serviceUUID];
    UInt16 c = [self swap:characteristicUUID];
    NSData *sd = [[NSData alloc] initWithBytes:(char *)&s length:2];
    NSData *cd = [[NSData alloc] initWithBytes:(char *)&c length:2];
    CBUUID *su = [CBUUID UUIDWithData:sd];
    CBUUID *cu = [CBUUID UUIDWithData:cd];
    CBService *service = [self findServiceFromUUID:su p:self.activeOptoStimmer.peripheral];
    if (!service) {
        NSLog(@"Could not find service with UUID %s on peripheral with UUID %s\r\n",[self CBUUIDToString:su],[self UUIDToString:self.activeOptoStimmer.peripheral.identifier]);
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
    
    if (!characteristic) {
        NSLog(@"Could not find characteristic with UUID %s on service with UUID %s on peripheral with UUID %s\r\n",[self CBUUIDToString:cu],[self CBUUIDToString:su],[self UUIDToString:self.activeOptoStimmer.peripheral.identifier]);
        return;
    }
    
    NSLog(@"Reading characteristic %s on service %s",[self CBUUIDToString:cu], [self CBUUIDToString:su]);
    [self.activeOptoStimmer.peripheral readValueForCharacteristic:characteristic];
}

-(void) writeValue:(int)serviceUUID characteristicUUID:(int)characteristicUUID  data:(NSData *)data {
    NSLog(@"Entering writeValue(characteristicUUID : %i)",characteristicUUID);
    
    UInt8 bdata;
    [data getBytes:&bdata length:sizeof(UInt8)];
    
    UInt16 s = [self swap:serviceUUID];
    UInt16 c = [self swap:characteristicUUID];
    NSData *sd = [[NSData alloc] initWithBytes:(char *)&s length:2];
    NSData *cd = [[NSData alloc] initWithBytes:(char *)&c length:2];
    CBUUID *su = [CBUUID UUIDWithData:sd];
    CBUUID *cu = [CBUUID UUIDWithData:cd];
    CBService *service = [self findServiceFromUUID:su p:self.activeOptoStimmer.peripheral];
    if (!service) {
        NSLog(@"Could not find service with UUID %s on peripheral with UUID %s\r\n",[self CBUUIDToString:su],[self UUIDToString:self.activeOptoStimmer.peripheral.identifier]);
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
    if (!characteristic) {
        NSLog(@"Could not find characteristic with UUID %s on service with UUID %s on peripheral with UUID %s\r\n",[self CBUUIDToString:cu],[self CBUUIDToString:su],[self UUIDToString:self.activeOptoStimmer.peripheral.identifier]);
        return;
    }
     NSLog(@"Writing [%i] characteristic %s on service %s", bdata, [self CBUUIDToString:cu], [self CBUUIDToString:su]);
    [self.activeOptoStimmer.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
}

-(void) notification:(int)serviceUUID characteristicUUID:(int)characteristicUUID on:(BOOL)on {
    NSLog(@"[local] notification(%i)",on);
    UInt16 s = [self swap:serviceUUID];
    UInt16 c = [self swap:characteristicUUID];
    NSData *sd = [[NSData alloc] initWithBytes:(char *)&s length:2];
    NSData *cd = [[NSData alloc] initWithBytes:(char *)&c length:2];
    CBUUID *su = [CBUUID UUIDWithData:sd];
    CBUUID *cu = [CBUUID UUIDWithData:cd];
    CBService *service = [self findServiceFromUUID:su p:self.activeOptoStimmer.peripheral];
    if (!service) {
        NSLog(@"Could not find service with UUID %s on peripheral with UUID %s\r\n",[self CBUUIDToString:su],[self UUIDToString:self.activeOptoStimmer.peripheral.identifier]);
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
    if (!characteristic) {
        NSLog(@"Could not find characteristic with UUID %s on service with UUID %s on peripheral with UUID %s\r\n",[self CBUUIDToString:cu],[self CBUUIDToString:su],[self UUIDToString:self.activeOptoStimmer.peripheral.identifier]);
        return;
    }
    [self.activeOptoStimmer.peripheral setNotifyValue:on forCharacteristic:characteristic];
}

//-------------------------------------------------------------------------
//
// CBCentralManagerDelegate protocol methods beneeth here
// Documented in CoreBluetooth documentation
//
//-------------------------------------------------------------------------

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"[CM] didConnectPeripheral(peripheral)");
    NSLog(@"Connection to peripheral with UUID : %s\n",[self UUIDToString:peripheral.identifier]);
   // self.activePeripheral = peripheral;
    [peripheral discoverServices:nil];
    [central stopScan];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"[CM] didUpdateState Changed %d (%s)\r\n",central.state,[self centralManagerStateToString:central.state]);

}


- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"[CM] didDiscoverPeripheral");
    NSLog(@"Ad data :\n%@",advertisementData);
    NSLog(@"Hardware Name: %@",peripheral.name);
   // NSLog(@"Hardver ID: %@", peripheral.UUID);
    
    NSString * nameString = (NSString *)[advertisementData objectForKey:@"kCBAdvDataLocalName"];
    if(nameString != nil)
    {
        if ([nameString rangeOfString:@"OptoStimmer"].location != NSNotFound) {

            NSLog(@"Found OptoStimmer!...\n");
            NSLog(@"Signal strength: %ld\n",[RSSI longValue]);
            if([RSSI longValue]>maximumSignalStrength)
            {
                maximumSignalStrength = [RSSI longValue];

                self.peripherals = [[NSMutableArray alloc] initWithObjects:peripheral,nil];

            }
            else
            {
                NSLog(@"Avoid connecting to BT device since we have already found device that has greateer signal strength\n");
            }
        } else {
            NSLog(@"Peripheral not a OptoStimmer or callback was not because of a ScanResponse\n");
        }
    }
    else
    {
        NSLog(@"Name is nil");
    }

}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"[CM] didDisconnectPeripheral");
    self.peripherals = nil;
    [[self delegate] didDisconnectFromOptoStimmer]; //Let the UI Know it was successful.
}


//-------------------------------------------------------------------------
//
//
//CBPeripheralDelegate protocol methods beneeth here
//
//
//-------------------------------------------------------------------------

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    UInt16 characteristicUUID = [self CBUUIDToInt:characteristic.UUID];
    if (!error) {
        switch(characteristicUUID){
            case BYB_OPTOSTIMMER_CHAR_FREQUENCY_UUID:
            {
                char value;
                [characteristic.value getBytes:&value length:1];
                 NSNumber *numberFreq = [NSNumber numberWithUnsignedChar:(unsigned char)value];
                
                //self.activeOptoStimmer.frequency = [NSNumber numberWithFloat:[numberFreq floatValue]*0.5f];
                tempFrequency = [numberFreq floatValue];
                //NSLog(@"[peripheral] didUpdateValueForChar Freq (%s, %@)", [self CBUUIDToString:characteristic.UUID], self.activeOptoStimmer.frequency);
                break;
            }

            case BYB_OPTOSTIMMER_CHAR_DURATION_IN_5MS_INTERVALS_UUID:
            {
                char value;
                [characteristic.value getBytes:&value length:1];
                NSNumber *numberOf5msSteps = [NSNumber numberWithUnsignedChar:(unsigned char)value];
                tempDuration = [numberOf5msSteps floatValue];
               // self.activeOptoStimmer.duration = [NSNumber numberWithInt:[numberOf5msSteps intValue] * 8]; //Note: in 5ms steps.
               // NSLog(@"[peripheral] didUpdateValueForChar Duration (%s, %@ *8ms = %@)", [self CBUUIDToString:characteristic.UUID], [NSNumber numberWithUnsignedChar:(unsigned char)value], self.activeOptoStimmer.duration);
                break;
            }
            case BYB_OPTOSTIMMER_CHAR_RANDOMMODE_UUID:
            {
                char value;
                [characteristic.value getBytes:&value length:1];
                self.activeOptoStimmer.randomMode = [NSNumber numberWithBool:(bool)value];
                //[[self delegate] didFinsihReadingOptoStimmerValues];
                NSLog(@"[peripheral] didUpdateValueForChar Rand (%s, %@)", [self CBUUIDToString:characteristic.UUID], [NSNumber numberWithInt:(int)value]);
                break;
            }
            case BYB_OPTOSTIMMER_CHAR_GAIN_UUID:
            {
                char value;
                [characteristic.value getBytes:&value length:1];
                self.activeOptoStimmer.gain = [NSNumber numberWithUnsignedChar:(unsigned char)value];
                NSLog(@"[peripheral] didUpdateValueForChar Gain (%s, %@)", [self CBUUIDToString:characteristic.UUID], [NSNumber numberWithUnsignedChar:(unsigned char)value]);
                break;
            }
            case BYB_OPTOSTIMMER_CHAR_PULSEWIDTH_UUID:
            {
                char value;
                [characteristic.value getBytes:&value length:1];
                NSNumber *numberPulseWidth = [NSNumber numberWithUnsignedChar:(unsigned char)value];
                tempPulseWidthFirst = (UInt8)[numberPulseWidth unsignedIntValue];
               /* UInt16 tempNewValue = (UInt8)[numberPulseWidth unsignedIntValue];
                
                uint tempPulseWidth = self.activeOptoStimmer.pulseWidth.unsignedIntValue;
                
                UInt16 resultantPulseWidth = (tempPulseWidth & 0xFF00) | tempNewValue;
                
                self.activeOptoStimmer.pulseWidth = [NSNumber numberWithUnsignedInteger:resultantPulseWidth];
                NSLog(@"[peripheral] didUpdateValueForChar PW   (%s, %@)  (freq: %@)", [self CBUUIDToString:characteristic.UUID], self.activeOptoStimmer.pulseWidth,self.activeOptoStimmer.frequency );
                */
                break;
            }
            case BYB_OPTOSTIMMER_CHAR_PULSE_WIDTH_SEC_UUID:
            {
            
                char value;
                
                [characteristic.value getBytes:&value length:1];
                NSNumber *numberPulseWidth = [NSNumber numberWithUnsignedChar:(unsigned char)value];
                tempPulseWidthSecond = (UInt8)[numberPulseWidth unsignedIntValue];
              /*  UInt16 tempNewValue = (UInt8)[numberPulseWidth unsignedIntValue];
                
                uint tempPulseWidth = self.activeOptoStimmer.pulseWidth.unsignedIntValue;
            
                UInt16 resultantPulseWidth = (tempPulseWidth & 0x00FF) | (tempNewValue<<8);
            
                self.activeOptoStimmer.pulseWidth = [NSNumber numberWithUnsignedInteger:resultantPulseWidth];
                NSLog(@"[peripheral] didUpdateValueForChar PW   (%s, %@)  (freq: %@)", [self CBUUIDToString:characteristic.UUID], self.activeOptoStimmer.pulseWidth,self.activeOptoStimmer.frequency );
                */
                break;
            }
            case BATTERY_CHAR_BATTERYLEVEL_UUID:
            {
                char value;
                [characteristic.value getBytes:&value length:1];
                self.activeOptoStimmer.batteryLevel = [NSNumber numberWithInt:(int)value];
                break;
            }
            case DEVICE_INFO_CHAR_FIRMWARE_UUID:
            {
                
                //char *value = (char *)malloc((10)*sizeof(char));
                //[characteristic.value getBytes:&value length:];
                NSString *fwString = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
                self.activeOptoStimmer.firmwareVersion = [fwString stringByTrimmingCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];//[NSString stringWithUTF8String:value];
                [self recalculateParametersBasedOnFirmware];
                NSLog(@"Firmware version: %@", self.activeOptoStimmer.firmwareVersion);
                break;
            }
            case DEVICE_INFO_CHAR_HARDWARE_UUID:
            {
                char value;
                [characteristic.value getBytes:&value length:10];
                self.activeOptoStimmer.hardwareVersion = [NSString
                    stringWithUTF8String:&value];
                
                [[self delegate] didFinsihReadingOptoStimmerValues];
                break;
            }
                
                
        }
    }
    else {
        NSLog(@"updateValueForCharacteristic failed !");
    }
}

- (void) recalculateParametersBasedOnFirmware
{
    NSLog(@"Recalculate Parameters based on firmware\n");
    if([self.activeOptoStimmer.firmwareVersion  isEqualToString:@"0.81"] || [self.activeOptoStimmer.firmwareVersion  isEqualToString:@"0.8"])
    {//2 sec max and pulse width encoded with 2 bytes
        self.activeOptoStimmer.frequency = [NSNumber numberWithFloat:tempFrequency*0.5f];
        self.activeOptoStimmer.duration = [NSNumber numberWithInt:(int)(tempDuration * 8)];
        self.activeOptoStimmer.pulseWidth = [NSNumber numberWithUnsignedInteger:(tempPulseWidthFirst & 0x00FF) | (tempPulseWidthSecond<<8)];
    }
    else if([self.activeOptoStimmer.firmwareVersion isEqualToString:@"1.0"])
    {//old one with pulse width that works 1-255
        self.activeOptoStimmer.frequency = [NSNumber numberWithFloat:tempFrequency];
        self.activeOptoStimmer.duration = [NSNumber numberWithInt:(int)(tempDuration * 5)];
        self.activeOptoStimmer.pulseWidth = [NSNumber numberWithUnsignedInteger:tempPulseWidthFirst];
    }
    else
    {//all other. Not recognized.
        //Use newest configuration
        self.activeOptoStimmer.frequency = [NSNumber numberWithFloat:tempFrequency*0.5f];
        self.activeOptoStimmer.duration = [NSNumber numberWithInt:(int)(tempDuration * 8)];
        self.activeOptoStimmer.pulseWidth = [NSNumber numberWithUnsignedInteger:(tempPulseWidthFirst & 0x00FF) | (tempPulseWidthSecond<<8)];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unrecognized hardver version"
                                                        message:@"We can't recognize hardware version of OptoStimmer. Please update application and try to connect again."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@"[peripheral] didDiscoverServices()");
    if (!error) {
        NSLog(@"Services of peripheral with UUID : %s found\r\n",[self UUIDToString:peripheral.identifier]);
        [self getAllCharacteristicsFromOptoStimmer:peripheral];
    }
    else {
        NSLog(@"Service discovery was unsuccessfull !\r\n");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSLog(@"[peripheral] didDiscoverCharacteristicsForService(%s)",[self CBUUIDToString:service.UUID]);
    if (!error) {
        for(int i=0; i < service.characteristics.count; i++) {
            CBCharacteristic *c = [service.characteristics objectAtIndex:i];
            NSLog(@"[peripheral] Found characteristic %s",[ self CBUUIDToString:c.UUID]);
            CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count - 1)];
            if([self compareCBUUID:service.UUID UUID2:s.UUID]) {
                //NSLog(@"Finished discovering characteristics");
                //[[self delegate] keyfobReady];
                NSLog(@"Finished discovering characteristics");
                
                //[self readValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_FREQUENCY_UUID];
                if ( !self.activeOptoStimmer.isLoadingParameters ){
                    self.activeOptoStimmer.isLoadingParameters = @1;
                    
                    [self readValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_FREQUENCY_UUID];
                    [self readValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_PULSEWIDTH_UUID];
                    [self readValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_PULSE_WIDTH_SEC_UUID];
                    [self readValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_DURATION_IN_5MS_INTERVALS_UUID];
                    [self readValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_RANDOMMODE_UUID];
                    [self readValue:BYB_OPTOSTIMMER_SERVICE_UUID characteristicUUID:BYB_OPTOSTIMMER_CHAR_GAIN_UUID];
                    [self readValue:BATTERY_SERVICE_UUID characteristicUUID:
                        BATTERY_CHAR_BATTERYLEVEL_UUID];
                    [self readValue:DEVICE_INFO_SERVICE_UUID characteristicUUID:
                        DEVICE_INFO_CHAR_FIRMWARE_UUID];
                    [self readValue:DEVICE_INFO_SERVICE_UUID characteristicUUID:
                        DEVICE_INFO_CHAR_HARDWARE_UUID];
                    [self.delegate optoStimmerReady];
                }
            }
        }
    }
    else {
        NSLog(@"[peripheral] Error in didDiscoverCharacteristicsForService(%s)",[self CBUUIDToString:service.UUID]);
        
    }
}

/*****************************
 *                           *
 *   UUID Utility Functions  *
 *                           *
 *****************************/

-(UInt16) swap:(UInt16)s {
    UInt16 temp = s << 8;
    temp |= (s >> 8);
    return temp;
}

-(const char *) CBUUIDToString:(CBUUID *) UUID {
    return [[UUID.data description] cStringUsingEncoding:NSStringEncodingConversionAllowLossy];
}

-(const char *) UUIDToString:(NSUUID*)UUID {
    if (!UUID) return "NULL";
    NSLog(@"UUID To String Enter");
    //CFStringRef s = CFUUIDCreateString(NULL, UUID);
    //return CFStringGetCStringPtr(s, 0);
    
    return "NULL";
}

-(BOOL)compareNSUUID:(NSUUID*)uuid1 UUID2:(NSUUID*)uuid2
{
    return [uuid1 isEqual:uuid2];
}

-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2 {
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1];
    [UUID2.data getBytes:b2];
    if (memcmp(b1, b2, UUID1.data.length) == 0)return 1;
    else return 0;
}

-(int) compareCBUUIDToInt:(CBUUID *)UUID1 UUID2:(UInt16)UUID2 {
    char b1[16];
    [UUID1.data getBytes:b1];
    UInt16 b2 = [self swap:UUID2];
    if (memcmp(b1, (char *)&b2, 2) == 0) return 1;
    else return 0;
}

-(UInt16) CBUUIDToInt:(CBUUID *) UUID {
    unsigned char b1[16];
    [UUID.data getBytes:b1];
    return ((b1[0] << 8) | b1[1]);
}

-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p {
    for(int i = 0; i < p.services.count; i++) {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID]) return s;
    }
    return nil;
}

-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    for(int i=0; i < service.characteristics.count; i++) {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([self compareCBUUID:c.UUID UUID2:UUID]) return c;
    }
    return nil; //Characteristic not found on this service
}

- (const char *) centralManagerStateToString: (int)state{
    switch(state) {
        case CBCentralManagerStateUnknown:
            return "State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return "State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return "State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return "State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return "State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return "State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return "State unknown";
    }
    return "Unknown state";
}

- (void) printPeripheralInfo:(CBPeripheral*)peripheral {
    //CFStringRef s = CFUUIDCreateString(NULL, peripheral.UUID);
    NSLog(@"------------------------------------\n");
    NSLog(@"Peripheral Info :\r\n");
    //NSLog(@"UUID : %s\n",CFStringGetCStringPtr(s, 0));
    NSLog(@"RSSI : %d\n",[peripheral.RSSI intValue]);
    NSLog(@"Name : %s\n",[peripheral.name UTF8String]);
    NSLog(@"-------------------------------------\n");
    
}

- (void) printKnownPeripherals {
    int i;
    NSLog(@"List of currently known peripherals : \n");
    for (i=0; i < self->_peripherals.count; i++)
    {
        //CBPeripheral *p = [self->_peripherals objectAtIndex:i];
        
        //[GJG to Fix] CFUUIDCreateString crashes on new OptoStimmeres.???
        
        //CFStringRef s = CFUUIDCreateString(NULL, p.UUID);
        //NSLog(@"%d  |  %s\n",i,CFStringGetCStringPtr(s, 0));
        //[self printPeripheralInfo:p];
    }
}


@end

