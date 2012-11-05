//
//  CardexViewController.m
//  Lib
//
//  Created by lingguang1997 on 10/29/12.
//  Copyright (c) 2012 lingguang1997. All rights reserved.
//

#import "Cardex.h"

@interface CardexViewController ()

@end

@implementation CardexViewController
@synthesize cardexView = _cardexView;
@synthesize dataItems = _dataItems;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.cardexView = [[CardexView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_cardexView];

    //Dummy Data
    self.dataItems = [NSMutableArray arrayWithCapacity:10];
    for (int i = 0; i < 30; i++) {
        [_dataItems addObject:[NSNumber numberWithInteger:i]];
    }
    //_cardexView.firstItemViewIndex = 10;

    _cardexView.dataSource = self;

    //[_cardexView reloadData];
    //NSLog(@"======%@", _cardexView.contentView.subviews);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSUInteger)numberOfItemsInCardexView:(CardexView *)cardexView {
    if (_dataItems) {
        return [_dataItems count];
    }
    return 0;
}

- (UIView *)cardexView:(CardexView *)cardexView
    viewForItemAtIndex:(NSUInteger)index
           reusingView:(UIView *)view {
    if (_dataItems == nil) {
        return nil;
    }
    UILabel *lbl = (UILabel *)view;
    if (lbl == nil) {
        lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
        lbl.textAlignment = NSTextAlignmentCenter;
    } 
    lbl.text = [NSString stringWithFormat:@"%d", [[_dataItems objectAtIndex:index] intValue]];
    lbl.tag = index;
    return lbl;
}

- (CGPoint)firstItemViewCenter:(CardexView *)cardexView {
    return CGPointMake(cardexView.frame.size.width / 2, cardexView.frame.size.height / 2);
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end