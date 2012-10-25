//
//  WAFirstUsePhotoImportViewController.m
//  wammer
//
//  Created by kchiu on 12/10/24.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFirstUsePhotoImportViewController.h"
#import "WADefines.h"

@interface WAFirstUsePhotoImportViewController ()

@end

@implementation WAFirstUsePhotoImportViewController

- (void)viewDidLoad {

	[super viewDidLoad];
	self.navigationItem.hidesBackButton = YES;
	self.navigationItem.rightBarButtonItem.enabled = NO;

}

#pragma mark UITableView delegates

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	UITableViewCell *hitCell = [tableView cellForRowAtIndexPath:indexPath];

	if (hitCell == self.enablePhotoImportCell) {

		self.enablePhotoImportCell.accessoryType = UITableViewCellAccessoryCheckmark;
		self.disablePhotoImportCell.accessoryType = UITableViewCellAccessoryNone;
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kWAPhotoImportEnabled];
		[[NSUserDefaults standardUserDefaults] synchronize];

		self.navigationItem.rightBarButtonItem.enabled = YES;

	} else if (hitCell == self.disablePhotoImportCell) {

		self.disablePhotoImportCell.accessoryType = UITableViewCellAccessoryCheckmark;
		self.enablePhotoImportCell.accessoryType = UITableViewCellAccessoryNone;
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kWAPhotoImportEnabled];
		[[NSUserDefaults standardUserDefaults] synchronize];

		self.navigationItem.rightBarButtonItem.enabled = YES;

	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];

}

@end
