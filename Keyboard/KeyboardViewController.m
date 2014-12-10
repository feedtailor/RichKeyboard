//
//  Copyright (c) 2014 feedtailor Inc. All rights reserved.
//


#import "KeyboardViewController.h"
#import "../Defines.h"

@import CoreBluetooth;

@interface KeyboardViewController () <CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDataSource, UITableViewDelegate>
{
    dispatch_queue_t queue;
    BOOL scanning;
}

@property (strong, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;
@property (weak, nonatomic) IBOutlet UILabel *helpLabel;

@property (nonatomic, strong) CBCentralManager* centralMgr;
@property (nonatomic, strong) CBPeripheral* peripheral;
@property (nonatomic, strong) CBCharacteristic* characteristic;

@property (nonatomic, strong) NSMutableArray* peripherals;

@end

@implementation KeyboardViewController

- (void)updateViewConstraints {
    [super updateViewConstraints];
    
    // Add custom view sizing constraints here
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UINib *nib = [UINib nibWithNibName:@"KeyboardViewController" bundle:nil];
    [nib instantiateWithOwner:self options:nil];
    [self.inputView addSubview:self.contentView];
    
    UIBlurEffect* blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView* v = [[UIVisualEffectView alloc] initWithEffect:blur];
    v.frame = self.contentView.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:v];
    [self.contentView sendSubviewToBack:v];
    
    self.peripherals = [NSMutableArray array];
    self.tableView.layer.cornerRadius = 8;
    self.tableView.layer.masksToBounds = YES;
    
    queue = dispatch_queue_create("central", nil);
    self.centralMgr = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    self.contentView.frame = self.inputView.bounds;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated
}

- (void)textWillChange:(id<UITextInput>)textInput {
    // The app is about to change the document's contents. Perform any preparation here.
}

- (void)textDidChange:(id<UITextInput>)textInput {
    // The app has just changed the document's contents, the document context has been updated.
}

- (IBAction)changeKeyboard:(id)sender
{
    [self advanceToNextInputMode];
}

- (IBAction)disconnect:(id)sender
{
    [self stopScan];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startScan];
    });
}


-(void) startScan
{
    self.infoLabel.text = NSLocalizedString(@"_searching_", @"");

    scanning = YES;
    [self refreshMessages];

    CBUUID* uuidService = [CBUUID UUIDWithString:SERVICE_UUID];
    [self.centralMgr scanForPeripheralsWithServices:[NSArray arrayWithObject:uuidService] options:nil];
}

-(void) stopScan
{
    self.infoLabel.text = @"";

    if (self.peripheral) {
        [self.centralMgr cancelPeripheralConnection:self.peripheral];
        self.peripheral = nil;
    }
    
    [self.peripherals removeAllObjects];
    [self.tableView reloadData];
    [self.centralMgr stopScan];
    
    scanning = NO;
    [self refreshMessages];
}

-(void) refreshMessages
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:NO];
        return;
    }
    
    if (!scanning) {
        // 非スキャン
        self.helpLabel.text = @"";
    } else {
        if (self.peripheral) {
            // 接続中
            self.helpLabel.text = @"";
        } else if ([self.peripherals count] > 0) {
            // デバイス見つかってる
            self.helpLabel.text = NSLocalizedString(@"_help_select_", @"");
        } else {
            self.helpLabel.text = NSLocalizedString(@"_help_searching_", @"");
        }
    }
}

#pragma mark - CBCentralManager

-(void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            [self startScan];
        }
            break;
        case CBCentralManagerStatePoweredOff:
        case CBCentralManagerStateUnauthorized:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.infoLabel.text = NSLocalizedString(@"_bluetooth_error_", @"");
            });
        }
            break;
        default:
            break;
    }
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if ([self.peripherals containsObject:aPeripheral]) {
        return;
    }
    
    [self.peripherals addObject:aPeripheral];
    
    [self refreshMessages];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.infoLabel.text = [error localizedDescription];
        });
    }
    
    if ([self.peripheral isEqual:aPeripheral]) {
        self.peripheral = nil;
    }
    if ([self.peripherals containsObject:aPeripheral]) {
        [self.peripherals removeObject:aPeripheral];

        [self refreshMessages];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.infoLabel.text = [error localizedDescription];
        });
    }

    if ([self.peripheral isEqual:aPeripheral]) {
        self.peripheral = nil;
    }
    if ([self.peripherals containsObject:aPeripheral]) {
        [self.peripherals removeObject:aPeripheral];
        
        [self refreshMessages];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - CBPeripheral

- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral
{
    [peripheral discoverServices:nil];
}

- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.infoLabel.text = [error localizedDescription];
        });
    }

    for (CBService* service in aPeripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:SERVICE_UUID]]) {
            [aPeripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CHARACTERISTIC_UUID]] forService:service];
        }
    }
}

- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.infoLabel.text = [error localizedDescription];
        });
    }

    @synchronized (self) {
        for (CBCharacteristic* cha in service.characteristics) {
            if ([cha.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_UUID]]) {
                self.characteristic = cha;
                
                [aPeripheral setNotifyValue:YES forCharacteristic:cha];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.infoLabel.text = NSLocalizedString(@"_connected_", @"");
                });
            }
        }
    }
}

- (void) peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        
        return;
    }
    
    NSData* d = characteristic.value;

    if (!d || [d length] == 0) {
        return;
    }

    if ([d length] == 1) {
        uint8_t cmd = ((uint8_t*)[d bytes])[0];
        switch (cmd) {
            case COMMAND_DISCONNECT:
                [self disconnect:nil];
                return;
                break;
            case COMMAND_CHAR_BACKWARD:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.textDocumentProxy adjustTextPositionByCharacterOffset:-1];
                });
                return;
            }
                break;
            case COMMAND_CHAR_FORWARD:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.textDocumentProxy adjustTextPositionByCharacterOffset:1];
                });
                return;
            }
                break;
            default:
                break;
        }
    }
    
    NSString* str = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([str isEqualToString:BACKWARD_STRING]) {
            [self.textDocumentProxy deleteBackward];
        } else {
            [self.textDocumentProxy insertText:str];
        }
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices
{
}

#pragma mark - UITableView

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.peripherals count];
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    CBPeripheral* peripheral = [self.peripherals objectAtIndex:indexPath.row];
    cell.textLabel.text = peripheral.name;
    if (self.peripheral && [peripheral isEqual:self.peripheral]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    CBPeripheral* peripheral = [self.peripherals objectAtIndex:indexPath.row];
    
    if (self.peripheral) {
        [self.centralMgr cancelPeripheralConnection:self.peripheral];
        
        if ([self.peripheral isEqual:peripheral]) {
            // 接続中のをタップ
            self.peripheral = nil;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            
            self.infoLabel.text = NSLocalizedString(@"_searching_", @"");
            [self refreshMessages];

            return;
        }
    }
    
    self.peripheral = [self.peripherals objectAtIndex:indexPath.row];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    self.infoLabel.text = NSLocalizedString(@"_connecting_", @"");
    [self refreshMessages];
    
    [self.centralMgr connectPeripheral:self.peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: @YES}];
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return floorf(tableView.frame.size.height / 3);
}

@end
