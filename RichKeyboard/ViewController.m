//
//  Copyright (c) 2014 feedtailor Inc. All rights reserved.
//


#import "ViewController.h"
#import "../Defines.h"

#define TOOLBAR_HEIGHT  (60)

@import CoreBluetooth;

@interface ViewController () <CBPeripheralManagerDelegate, UITextViewDelegate>
{
    dispatch_queue_t queue;
}

@property (nonatomic, strong) CBPeripheralManager* peripheralMgr;
@property (nonatomic, strong) CBMutableService* service;
@property (nonatomic, strong) CBCentral* central;
@property (nonatomic, strong) CBMutableCharacteristic* characteristic;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UILabel *helpLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]}];

    self.peripheralMgr = [[CBPeripheralManager alloc] initWithDelegate:self queue:queue];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewChanged:) name:UITextViewTextDidChangeNotification object:self.textView];
    
    UIView* accessoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
    UIToolbar* toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
    [accessoryView addSubview:toolbar];
    UIBarButtonItem* sp = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    [sp setWidth:20];
    toolbar.items = @[
                      [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"09-arrow-west"] style:UIBarButtonItemStylePlain target:self action:@selector(charBackward:)],
                      sp,
                      [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"02-arrow-east"] style:UIBarButtonItemStylePlain target:self action:@selector(charForward:)],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                      [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"delete"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteBackward:)],
                      ];
    
    self.textView.alpha = 0;
    self.textView.inputAccessoryView = accessoryView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
}

-(IBAction)charBackward:(id)sender
{
    uint8_t cmd = COMMAND_CHAR_BACKWARD;
    [self sendData:[NSData dataWithBytes:&cmd length:1]];
}

-(IBAction)charForward:(id)sender
{
    uint8_t cmd = COMMAND_CHAR_FORWARD;
    [self sendData:[NSData dataWithBytes:&cmd length:1]];
}

- (IBAction)connectOrDisconnect:(id)sender
{
    [self.textView resignFirstResponder];
    [self stop];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self start];
    });
}

-(void) start
{
    self.title = NSLocalizedString(@"_waiting_", @"");
    self.helpLabel.text = NSLocalizedString(@"_help_waiting_", @"");
    
    CBUUID* uuidService = [CBUUID UUIDWithString:SERVICE_UUID];
    NSDictionary* advertiseDict = @{
                                    CBAdvertisementDataServiceUUIDsKey: @[uuidService],
                                    CBAdvertisementDataLocalNameKey: [[UIDevice currentDevice] name],
                                    };
    
    [self.peripheralMgr startAdvertising:advertiseDict];
}

-(void) stop
{
    [self.peripheralMgr stopAdvertising];
}


-(void) textViewChanged:(id)sender
{
    if (self.textView.markedTextRange) {
        self.textView.alpha = 1;
        return;
    }
    
    NSData* data = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data];
    self.textView.text = @"";
}

-(void) deleteBackward:(id)sender
{
    [self sendData:[BACKWARD_STRING dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void) sendData:(NSData*)data
{
    self.textView.alpha = 0;

    if (self.characteristic && self.central) {
        [self.peripheralMgr updateValue:data forCharacteristic:self.characteristic onSubscribedCentrals:@[self.central]];
    }
}

#pragma mark - CBPeripheralManager

-(void) peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
        {
            self.characteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTIC_UUID] properties:CBCharacteristicPropertyWriteWithoutResponse | CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsWriteable];
            
            CBUUID* uuidService = [CBUUID UUIDWithString:SERVICE_UUID];
            self.service = [[CBMutableService alloc] initWithType:uuidService primary:YES];
            self.service.characteristics = @[self.characteristic];
            
            [self.peripheralMgr addService:self.service];
        }
            break;
        case CBPeripheralManagerStateUnauthorized:
        case CBPeripheralManagerStatePoweredOff:
        {
            self.title = @"";
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", @"") message:NSLocalizedString(@"_bluetooth_error_", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"_dismiss_", @"") otherButtonTitles:nil];
            [alert show];
        }
            break;
            
        default:
            break;
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error) {
        self.title = @"";
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:[error localizedDescription] message:[error localizedFailureReason] delegate:nil cancelButtonTitle:NSLocalizedString(@"_dismiss_", @"") otherButtonTitles:nil];
        [alert show];
        return;
    }
    [self start];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error;
{
    if (error) {
        self.title = @"";
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:[error localizedDescription] message:[error localizedFailureReason] delegate:nil cancelButtonTitle:NSLocalizedString(@"_dismiss_", @"") otherButtonTitles:nil];
        [alert show];
        return;
    }
}

-(void) peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    if ([self.characteristic isEqual:characteristic]) {
        self.central = central;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.textView becomeFirstResponder];
        });
    }
}

-(void) peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    if ([self.characteristic isEqual:characteristic]) {
        self.central = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.textView resignFirstResponder];
        });
    }
}

#pragma mark - UITextView

-(void) textViewDidBeginEditing:(UITextView *)textView
{
    self.title = NSLocalizedString(@"_connected_", @"");

    self.helpLabel.text = @"";
    self.helpLabel.hidden = YES;
    [self stop];
}

-(void) textViewDidEndEditing:(UITextView *)textView
{
    self.helpLabel.hidden = NO;
    
    uint8_t cmd = COMMAND_DISCONNECT;
    [self sendData:[NSData dataWithBytes:&cmd length:1]];

    [self start];
}

@end
