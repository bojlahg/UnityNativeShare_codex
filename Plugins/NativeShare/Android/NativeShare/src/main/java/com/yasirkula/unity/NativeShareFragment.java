package com.yasirkula.unity;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.fragment.app.Fragment;

import java.util.ArrayList;
import java.util.List;

/**
 * Created by yasirkula on 11.07.2020.
 */

// Displays standard ACTION_SEND share sheet and waits for its result via onActivityResult and NativeShareBroadcastListener
public class NativeShareFragment extends Fragment
{
	private ActivityResultLauncher<Intent> shareLauncher;

	public static final String TARGET_PACKAGE_ID = "NS_TARGET_PACKAGE";
	public static final String TARGET_CLASS_ID = "NS_TARGET_CLASS";
	public static final String FILES_ID = "NS_FILES";
	public static final String MIMES_ID = "NS_MIMES";
	public static final String EMAIL_RECIPIENTS_ID = "NS_EMAIL_RECIPIENTS";
	public static final String SUBJECT_ID = "NS_SUBJECT";
	public static final String TEXT_ID = "NS_TEXT";
	public static final String TITLE_ID = "NS_TITLE";

	@Override
	public void onCreate( Bundle savedInstanceState )
	{
		super.onCreate( savedInstanceState );

		shareLauncher = registerForActivityResult( new ActivityResultContracts.StartActivityForResult(), result -> handleShareResult( result.getResultCode() ) );

		if( NativeShare.shareResultReceiver == null )
			handleShareResult( Activity.RESULT_CANCELED );
		else
		{
			final ArrayList<Uri> fileUris = new ArrayList<Uri>();
			final Intent shareIntent = NativeShare.CreateIntentFromBundle( getActivity(), getArguments(), fileUris );
			final String title = getArguments().getString( NativeShareFragment.TITLE_ID );

			shareIntent.setFlags( Intent.FLAG_ACTIVITY_NEW_TASK );

			try
			{
				Intent chooserIntent;
				if( Build.VERSION.SDK_INT < 22 )
					chooserIntent = Intent.createChooser( shareIntent, title );
				else
					chooserIntent = Intent.createChooser( shareIntent, title, NativeShareBroadcastListener.Initialize( getActivity() ) );

				if( fileUris.size() > 0 )
				{
					List<ResolveInfo> shareTargets;
					if( Build.VERSION.SDK_INT >= 33 )
						shareTargets = getActivity().getPackageManager().queryIntentActivities( chooserIntent, PackageManager.ResolveInfoFlags.of( PackageManager.MATCH_DEFAULT_ONLY ) );
					else
						shareTargets = getActivity().getPackageManager().queryIntentActivities( chooserIntent, PackageManager.MATCH_DEFAULT_ONLY );

					NativeShare.GrantURIPermissionsToShareIntentTargets( getActivity(), shareTargets, fileUris );
				}

				shareLauncher.launch( chooserIntent );
			}
			catch( ActivityNotFoundException e )
			{
				Toast.makeText( getActivity(), "No apps can perform this action.", Toast.LENGTH_LONG ).show();
				handleShareResult( Activity.RESULT_CANCELED );
			}
		}
	}

	private void handleShareResult( int resultCode )
	{
		if( NativeShare.shareResultReceiver != null )
		{
			Log.d( "Unity", "Reported share result (may not be correct): " + ( resultCode == Activity.RESULT_OK ) );

			if( resultCode == Activity.RESULT_OK )
				NativeShare.shareResultReceiver.OnShareCompleted( 1, "" ); // 1: Shared
			else
			{
				if( Build.VERSION.SDK_INT < 22 )
				{
					// On older Android versions, unfortunately we can't determine whether or not user has picked an app
					// from the share sheet
					NativeShare.shareResultReceiver.OnShareCompleted( 0, "" ); // 0: Unknown
				}
				else
				{
					// On newer Android versions, it is safe to send NotShared result since for a successful share,
					// ShareResultBroadcastReceiver will override the result
					NativeShare.shareResultReceiver.OnShareCompleted( 2, "" ); // 2: NotShared
				}
			}
		}
		else
			Log.e( "Unity", "NativeShareResultReceiver was null!" );

		getParentFragmentManager().beginTransaction().remove( this ).commitAllowingStateLoss();
	}
}
