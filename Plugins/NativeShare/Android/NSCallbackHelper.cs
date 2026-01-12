#if UNITY_EDITOR || UNITY_ANDROID
using System.Collections;
using UnityEngine;

namespace NativeShareNamespace
{
	public class NSCallbackHelper : MonoBehaviour
	{
		public NativeShare.ShareResultCallback callback;

		private NativeShare.ShareResult result = NativeShare.ShareResult.Unknown;
		private string shareTarget = null;

		private bool resultReceived;
		private bool waitingForResult;
		private float focusResultStartTime;
		private Coroutine focusResultCoroutine;

		private const float FocusResultTimeout = 1.5f;

		private void Awake()
		{
			DontDestroyOnLoad( gameObject );
		}

		private void Update()
		{
			if( resultReceived )
			{
				resultReceived = false;

				try
				{
					if( callback != null )
						callback( result, shareTarget );
				}
				finally
				{
					Destroy( gameObject );
				}
			}
		}

		private void OnApplicationFocus( bool focus )
		{
			if( focus )
			{
				// Share sheet is closed and now Unity activity is running again. Send Unknown result if OnShareCompleted wasn't called
				if( focusResultCoroutine != null )
					StopCoroutine( focusResultCoroutine );

				waitingForResult = true;
				focusResultStartTime = Time.realtimeSinceStartup;
				focusResultCoroutine = StartCoroutine( DelayedFocusResult() );
			}
		}

		private IEnumerator DelayedFocusResult()
		{
			yield return new WaitForSeconds( FocusResultTimeout );

			focusResultCoroutine = null;

			if( waitingForResult && !resultReceived && Time.realtimeSinceStartup - focusResultStartTime >= FocusResultTimeout )
			{
				waitingForResult = false;
				resultReceived = true;
			}
		}

		public void OnShareCompleted( int resultRaw, string shareTarget )
		{
			NativeShare.ShareResult shareResult = (NativeShare.ShareResult) resultRaw;

			if( result == NativeShare.ShareResult.Unknown )
			{
				result = shareResult;
				this.shareTarget = shareTarget;
			}
			else if( result == NativeShare.ShareResult.NotShared )
			{
				if( shareResult == NativeShare.ShareResult.Shared )
				{
					result = NativeShare.ShareResult.Shared;
					this.shareTarget = shareTarget;
				}
				else if( shareResult == NativeShare.ShareResult.NotShared && !string.IsNullOrEmpty( shareTarget ) )
					this.shareTarget = shareTarget;
			}
			else
			{
				if( shareResult == NativeShare.ShareResult.Shared && !string.IsNullOrEmpty( shareTarget ) )
					this.shareTarget = shareTarget;
			}

			waitingForResult = false;
			if( focusResultCoroutine != null )
			{
				StopCoroutine( focusResultCoroutine );
				focusResultCoroutine = null;
			}
			resultReceived = true;
		}
	}
}
#endif
