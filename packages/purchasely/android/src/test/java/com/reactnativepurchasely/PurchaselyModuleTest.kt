package com.reactnativepurchasely

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import io.purchasely.ext.*
import io.purchasely.models.PLYWebRedemptionContext
import io.purchasely.models.PLYWebRedemptionResult
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationType
import io.purchasely.storage.userData.PLYUserAttributeSource
import io.purchasely.storage.userData.PLYUserAttributeType
import io.purchasely.views.presentation.PLYThemeMode
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.junit.MockitoJUnitRunner

/**
 * Unit tests for PurchaselyModule
 *
 * These tests verify the module's behavior without requiring the full Android environment.
 */
@RunWith(MockitoJUnitRunner::class)
class PurchaselyModuleTest {

    @Mock
    private lateinit var reactContext: ReactApplicationContext

    private lateinit var purchaselyModule: PurchaselyModule

    @Before
    fun setUp() {
        reactContext = mock(ReactApplicationContext::class.java)
        purchaselyModule = PurchaselyModule(reactContext)
    }

    // region Module Initialization Tests

    @Test
    fun `module name should be Purchasely`() {
        assertEquals("Purchasely", purchaselyModule.name)
    }

    // endregion

    // region iOS-only API fallbacks

    @Test
    fun `sign promotional offer resolves null on Android`() {
        val promise = mock(Promise::class.java)

        purchaselyModule.signPromotionalOffer("product", "offer", promise)

        verify(promise).resolve(null)
    }

    // endregion

    // region Constants Tests

    @Test
    fun `getConstants should return non-null map`() {
        val constants = purchaselyModule.constants
        assertNotNull(constants)
    }

    @Test
    fun `getConstants should contain log level constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("logLevelDebug"))
        assertTrue(constants.containsKey("logLevelInfo"))
        assertTrue(constants.containsKey("logLevelWarn"))
        assertTrue(constants.containsKey("logLevelError"))
    }

    @Test
    fun `log level constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(LogLevel.DEBUG.ordinal, constants["logLevelDebug"])
        assertEquals(LogLevel.INFO.ordinal, constants["logLevelInfo"])
        assertEquals(LogLevel.WARN.ordinal, constants["logLevelWarn"])
        assertEquals(LogLevel.ERROR.ordinal, constants["logLevelError"])
    }

    @Test
    fun `getConstants should contain product result constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("productResultPurchased"))
        assertTrue(constants.containsKey("productResultCancelled"))
        assertTrue(constants.containsKey("productResultRestored"))
    }

    @Test
    fun `product result constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(PLYProductViewResult.PURCHASED.ordinal, constants["productResultPurchased"])
        assertEquals(PLYProductViewResult.CANCELLED.ordinal, constants["productResultCancelled"])
        assertEquals(PLYProductViewResult.RESTORED.ordinal, constants["productResultRestored"])
    }

    @Test
    fun `getConstants should contain subscription source constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("sourceAppStore"))
        assertTrue(constants.containsKey("sourcePlayStore"))
        assertTrue(constants.containsKey("sourceHuaweiAppGallery"))
        assertTrue(constants.containsKey("sourceAmazonAppstore"))
        assertTrue(constants.containsKey("sourceNone"))
    }

    @Test
    fun `subscription source constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(StoreType.APPLE_APP_STORE.ordinal, constants["sourceAppStore"])
        assertEquals(StoreType.GOOGLE_PLAY_STORE.ordinal, constants["sourcePlayStore"])
        assertEquals(StoreType.HUAWEI_APP_GALLERY.ordinal, constants["sourceHuaweiAppGallery"])
        assertEquals(StoreType.AMAZON_APP_STORE.ordinal, constants["sourceAmazonAppstore"])
        assertEquals(StoreType.NONE.ordinal, constants["sourceNone"])
    }

    @Test
    fun `getConstants should contain attribute constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("firebaseAppInstanceId"))
        assertTrue(constants.containsKey("airshipChannelId"))
        assertTrue(constants.containsKey("airshipUserId"))
        assertTrue(constants.containsKey("batchInstallationId"))
        assertTrue(constants.containsKey("adjustId"))
        assertTrue(constants.containsKey("appsflyerId"))
        // [ENM-04 / REC-11] present on both natives but never bridged before.
        assertTrue(constants.containsKey("oneSignalExternalId"))
        assertTrue(constants.containsKey("oneSignalUserId"))
        assertTrue(constants.containsKey("mixpanelDistinctId"))
        assertTrue(constants.containsKey("clevertapId"))
        assertTrue(constants.containsKey("sendinblueUserEmail"))
        assertTrue(constants.containsKey("iterableUserId"))
        assertTrue(constants.containsKey("iterableUserEmail"))
        assertTrue(constants.containsKey("atInternetIdClient"))
        assertTrue(constants.containsKey("amplitudeUserId"))
        assertTrue(constants.containsKey("amplitudeDeviceId"))
        assertTrue(constants.containsKey("mparticleUserId"))
        assertTrue(constants.containsKey("customerIoUserId"))
        assertTrue(constants.containsKey("customerIoUserEmail"))
        assertTrue(constants.containsKey("branchUserDeveloperIdentity"))
        assertTrue(constants.containsKey("moEngageUniqueId"))
        assertTrue(constants.containsKey("batchCustomUserId"))
    }

    @Test
    fun `attribute constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(Attribute.FIREBASE_APP_INSTANCE_ID.ordinal, constants["firebaseAppInstanceId"])
        assertEquals(Attribute.AIRSHIP_CHANNEL_ID.ordinal, constants["airshipChannelId"])
        assertEquals(Attribute.AIRSHIP_USER_ID.ordinal, constants["airshipUserId"])
        assertEquals(Attribute.BATCH_INSTALLATION_ID.ordinal, constants["batchInstallationId"])
        assertEquals(Attribute.ADJUST_ID.ordinal, constants["adjustId"])
        assertEquals(Attribute.APPSFLYER_ID.ordinal, constants["appsflyerId"])
        assertEquals(Attribute.ONESIGNAL_EXTERNAL_ID.ordinal, constants["oneSignalExternalId"])
        assertEquals(Attribute.ONESIGNAL_USER_ID.ordinal, constants["oneSignalUserId"])
        assertEquals(Attribute.MIXPANEL_DISTINCT_ID.ordinal, constants["mixpanelDistinctId"])
        assertEquals(Attribute.CLEVER_TAP_ID.ordinal, constants["clevertapId"])
    }

    @Test
    fun `getConstants should contain distribution type constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("consumable"))
        assertTrue(constants.containsKey("nonConsumable"))
        assertTrue(constants.containsKey("autoRenewingSubscription"))
        assertTrue(constants.containsKey("nonRenewingSubscription"))
        assertTrue(constants.containsKey("unknown"))
    }

    @Test
    fun `distribution type constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(DistributionType.CONSUMABLE.ordinal, constants["consumable"])
        assertEquals(DistributionType.NON_CONSUMABLE.ordinal, constants["nonConsumable"])
        assertEquals(DistributionType.RENEWING_SUBSCRIPTION.ordinal, constants["autoRenewingSubscription"])
        assertEquals(DistributionType.NON_RENEWING_SUBSCRIPTION.ordinal, constants["nonRenewingSubscription"])
        assertEquals(DistributionType.UNKNOWN.ordinal, constants["unknown"])
    }

    // [ENM-06 / REC-17] The v5 runningModeTransactionOnly / runningModePaywallObserver
    // constants were removed — only Observer / Full remain in v6.
    @Test
    fun `getConstants should contain running mode constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("runningModeObserver"))
        assertTrue(constants.containsKey("runningModeFull"))
    }

    @Test
    fun `running mode constants should be unique`() {
        val constants = purchaselyModule.constants

        val runningModes = setOf(
            constants["runningModeObserver"],
            constants["runningModeFull"]
        )

        assertEquals(2, runningModes.size)
    }

    @Test
    fun `getConstants should contain presentation type constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("presentationTypeNormal"))
        assertTrue(constants.containsKey("presentationTypeFallback"))
        assertTrue(constants.containsKey("presentationTypeDeactivated"))
        assertTrue(constants.containsKey("presentationTypeClient"))
    }

    @Test
    fun `presentation type constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(PLYPresentationType.NORMAL.ordinal, constants["presentationTypeNormal"])
        assertEquals(PLYPresentationType.FALLBACK.ordinal, constants["presentationTypeFallback"])
        assertEquals(PLYPresentationType.DEACTIVATED.ordinal, constants["presentationTypeDeactivated"])
        assertEquals(PLYPresentationType.CLIENT.ordinal, constants["presentationTypeClient"])
    }

    @Test
    fun `getConstants should contain theme mode constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("themeLight"))
        assertTrue(constants.containsKey("themeDark"))
        assertTrue(constants.containsKey("themeSystem"))
    }

    @Test
    fun `theme mode constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(PLYThemeMode.LIGHT.ordinal, constants["themeLight"])
        assertEquals(PLYThemeMode.DARK.ordinal, constants["themeDark"])
        assertEquals(PLYThemeMode.SYSTEM.ordinal, constants["themeSystem"])
    }

    @Test
    fun `getConstants should contain user attribute source constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("userAttributeSourcePurchasely"))
        assertTrue(constants.containsKey("userAttributeSourceClient"))
    }

    @Test
    fun `user attribute source constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(PLYUserAttributeSource.PURCHASELY.ordinal, constants["userAttributeSourcePurchasely"])
        assertEquals(PLYUserAttributeSource.CLIENT.ordinal, constants["userAttributeSourceClient"])
    }

    @Test
    fun `getConstants should contain user attribute type constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("userAttributeString"))
        assertTrue(constants.containsKey("userAttributeBoolean"))
        assertTrue(constants.containsKey("userAttributeInt"))
        assertTrue(constants.containsKey("userAttributeFloat"))
        assertTrue(constants.containsKey("userAttributeDate"))
        assertTrue(constants.containsKey("userAttributeStringArray"))
        assertTrue(constants.containsKey("userAttributeIntArray"))
        assertTrue(constants.containsKey("userAttributeFloatArray"))
        assertTrue(constants.containsKey("userAttributeBooleanArray"))
    }

    @Test
    fun `user attribute type constants should have correct ordinal values`() {
        val constants = purchaselyModule.constants

        assertEquals(PLYUserAttributeType.STRING.ordinal, constants["userAttributeString"])
        assertEquals(PLYUserAttributeType.BOOLEAN.ordinal, constants["userAttributeBoolean"])
        assertEquals(PLYUserAttributeType.INT.ordinal, constants["userAttributeInt"])
        assertEquals(PLYUserAttributeType.FLOAT.ordinal, constants["userAttributeFloat"])
        assertEquals(PLYUserAttributeType.DATE.ordinal, constants["userAttributeDate"])
        assertEquals(PLYUserAttributeType.STRING_ARRAY.ordinal, constants["userAttributeStringArray"])
        assertEquals(PLYUserAttributeType.INT_ARRAY.ordinal, constants["userAttributeIntArray"])
        assertEquals(PLYUserAttributeType.FLOAT_ARRAY.ordinal, constants["userAttributeFloatArray"])
        assertEquals(PLYUserAttributeType.BOOLEAN_ARRAY.ordinal, constants["userAttributeBooleanArray"])
    }

    // endregion

    // region Constants Count Test

    @Test
    fun `getConstants should have at least 50 constants`() {
        val constants = purchaselyModule.constants
        assertTrue("Expected at least 50 constants, got ${constants.size}", constants.size >= 50)
    }

    // endregion

    // region Constants Uniqueness Tests

    @Test
    fun `all log level constants should be unique`() {
        val constants = purchaselyModule.constants
        val logLevels = setOf(
            constants["logLevelDebug"],
            constants["logLevelInfo"],
            constants["logLevelWarn"],
            constants["logLevelError"]
        )
        assertEquals(4, logLevels.size)
    }

    @Test
    fun `all product result constants should be unique`() {
        val constants = purchaselyModule.constants
        val productResults = setOf(
            constants["productResultPurchased"],
            constants["productResultCancelled"],
            constants["productResultRestored"]
        )
        assertEquals(3, productResults.size)
    }

    @Test
    fun `all subscription source constants should be unique`() {
        val constants = purchaselyModule.constants
        val sources = setOf(
            constants["sourceAppStore"],
            constants["sourcePlayStore"],
            constants["sourceHuaweiAppGallery"],
            constants["sourceAmazonAppstore"],
            constants["sourceNone"]
        )
        assertEquals(5, sources.size)
    }

    @Test
    fun `all distribution type constants should be unique`() {
        val constants = purchaselyModule.constants
        val types = setOf(
            constants["consumable"],
            constants["nonConsumable"],
            constants["autoRenewingSubscription"],
            constants["nonRenewingSubscription"],
            constants["unknown"]
        )
        assertEquals(5, types.size)
    }

    @Test
    fun `all presentation type constants should be unique`() {
        val constants = purchaselyModule.constants
        val types = setOf(
            constants["presentationTypeNormal"],
            constants["presentationTypeFallback"],
            constants["presentationTypeDeactivated"],
            constants["presentationTypeClient"]
        )
        assertEquals(4, types.size)
    }

    @Test
    fun `all theme mode constants should be unique`() {
        val constants = purchaselyModule.constants
        val modes = setOf(
            constants["themeLight"],
            constants["themeDark"],
            constants["themeSystem"]
        )
        assertEquals(3, modes.size)
    }

    @Test
    fun `all user attribute type constants should be unique`() {
        val constants = purchaselyModule.constants
        val types = setOf(
            constants["userAttributeString"],
            constants["userAttributeBoolean"],
            constants["userAttributeInt"],
            constants["userAttributeFloat"],
            constants["userAttributeDate"],
            constants["userAttributeStringArray"],
            constants["userAttributeIntArray"],
            constants["userAttributeFloatArray"],
            constants["userAttributeBooleanArray"]
        )
        assertEquals(9, types.size)
    }

    // endregion

    // region Constants Value Range Tests

    @Test
    fun `all log level constants should be non-negative`() {
        val constants = purchaselyModule.constants

        assertTrue(constants["logLevelDebug"]!! >= 0)
        assertTrue(constants["logLevelInfo"]!! >= 0)
        assertTrue(constants["logLevelWarn"]!! >= 0)
        assertTrue(constants["logLevelError"]!! >= 0)
    }

    @Test
    fun `all product result constants should be non-negative`() {
        val constants = purchaselyModule.constants

        assertTrue(constants["productResultPurchased"]!! >= 0)
        assertTrue(constants["productResultCancelled"]!! >= 0)
        assertTrue(constants["productResultRestored"]!! >= 0)
    }

    // endregion

    // region User attribute read — array conversion (regression: E2E T14)

    /**
     * Reading an array-typed attribute (String[]/Integer[]/Float[]/Boolean[]) must go
     * through Arguments.makeNativeArray. Handing a raw Java array to promise.resolve()
     * throws "Cannot convert argument of type class [Ljava.lang.String;" at runtime
     * (Arguments.kt), which is what broke E2E T14 on device.
     */
    @Test
    fun `userAttribute resolves array attributes as a native array, not a raw java array`() {
        val promise = mock(Promise::class.java)
        val rawArray: Any = arrayOf("alpha", "beta", "gamma") // java.lang.String[]

        // WritableNativeArray is final + JNI-backed, so we can't mock its instances.
        // We only assert the routing: the raw array is turned into a List and handed to
        // Arguments.makeNativeArray (never resolved as-is).
        val purchaselyStatic = mockStatic(Purchasely::class.java)
        val argumentsStatic = mockStatic(Arguments::class.java)
        try {
            purchaselyStatic.`when`<Any> { Purchasely.userAttribute("e2e_str_arr") }
                .thenReturn(rawArray)

            purchaselyModule.userAttribute("e2e_str_arr", promise)

            // The array must be normalized to a List and converted, not resolved raw.
            argumentsStatic.verify { Arguments.makeNativeArray(listOf("alpha", "beta", "gamma")) }
            verify(promise, never()).resolve(rawArray)
        } finally {
            argumentsStatic.close()
            purchaselyStatic.close()
        }
    }

    // endregion

    // region closePresentation defensive onCloseRequested clear (Fix B)

    /**
     * [Fix B] `closePresentation` delegates to `Purchasely.closeAllScreens()`,
     * a programmatic close, and must never be mistaken for a native close
     * request. An embedded `PLYPresentationView` with no flow listener
     * re-reads its own `onCloseRequested` on a native SelfClose, so the
     * tracked Prepared's handler must be cleared before the SDK call is made,
     * or that path could re-emit CLOSE_REQUESTED for this JS-programmatic close.
     */
    @Test
    fun `closePresentation clears the tracked onCloseRequested handler before closing`() {
        val requestId = "req-close-clear-test"
        val prepared = PLYPresentationBase.builder()
            .placementId("PLACEMENT")
            .onCloseRequested { }
            .build()

        val requestsField = PurchaselyModule::class.java
            .getDeclaredField("activePresentationRequests")
            .apply { isAccessible = true }
        @Suppress("UNCHECKED_CAST")
        val requests = requestsField.get(null) as MutableMap<String, PLYPresentationBase.Prepared>
        requests[requestId] = prepared

        val purchaselyStatic = mockStatic(Purchasely::class.java)
        try {
            purchaselyModule.closePresentation(requestId)
        } finally {
            purchaselyStatic.close()
        }

        assertNull(prepared.onCloseRequested)
    }

    // endregion

    // region revokeDataProcessingConsent wire-string mapping (REC-15 / ENM-12)

    /**
     * [REC-15 / ENM-12] Pins mapPurposesFromReadableArray's mapping to the
     * native PLYDataProcessingPurpose enum, and locks in the "align en
     * douceur" widening: RN's own kebab-case singular strings AND the
     * SCREAMING_SNAKE_CASE plural convention used by the other Purchasely
     * SDKs must both resolve to the same native purpose.
     */
    @Test
    fun `revokeDataProcessingConsent accepts both kebab-case and SCREAMING_SNAKE_CASE wire strings`() {
        val mapper = PurchaselyModule::class.java
            .getDeclaredMethod("mapPurposesFromReadableArray", ReadableArray::class.java)
            .apply { isAccessible = true }

        @Suppress("UNCHECKED_CAST")
        fun map(vararg purposes: String) = mapper.invoke(
            purchaselyModule,
            JavaOnlyArray.of(*purposes)
        ) as Set<PLYDataProcessingPurpose>

        assertEquals(
            setOf(PLYDataProcessingPurpose.ThirdPartyIntegrations),
            map("third-party-integration")
        )
        assertEquals(
            setOf(PLYDataProcessingPurpose.ThirdPartyIntegrations),
            map("THIRD_PARTY_INTEGRATIONS")
        )
        assertEquals(
            setOf(PLYDataProcessingPurpose.AllNonEssentials),
            map("ALL_NON_ESSENTIALS")
        )
        assertEquals(
            setOf(
                PLYDataProcessingPurpose.Analytics,
                PLYDataProcessingPurpose.IdentifiedAnalytics,
                PLYDataProcessingPurpose.Campaigns,
                PLYDataProcessingPurpose.Personalization
            ),
            map("ANALYTICS", "IDENTIFIED_ANALYTICS", "CAMPAIGNS", "PERSONALIZATION")
        )
    }

    // endregion

    // region 6.1.0: anonymous user id + web redemption

    /**
     * `UUID.fromString` is lenient: it accepts a short form the iOS `NSUUID`
     * parser refuses. `parseCanonicalUuid` adds a round-trip check so one id
     * string is accepted, or refused, on both platforms.
     */
    @Test
    fun `parseCanonicalUuid accepts a canonical uuid`() {
        val parsed = parseCanonicalUuid("3f2504e0-4f89-11d3-9a0c-0305e82c3301")

        assertNotNull(parsed)
        assertEquals("3f2504e0-4f89-11d3-9a0c-0305e82c3301", parsed.toString())
    }

    @Test
    fun `parseCanonicalUuid accepts an uppercase uuid`() {
        val parsed = parseCanonicalUuid("3F2504E0-4F89-11D3-9A0C-0305E82C3301")

        assertNotNull(parsed)
        assertEquals("3f2504e0-4f89-11d3-9a0c-0305e82c3301", parsed.toString())
    }

    @Test
    fun `parseCanonicalUuid refuses the lenient short form that iOS refuses`() {
        assertNull(parseCanonicalUuid("1-2-3-4-5"))
    }

    @Test
    fun `parseCanonicalUuid refuses a value that is not a uuid`() {
        assertNull(parseCanonicalUuid("not-a-uuid"))
        assertNull(parseCanonicalUuid(""))
        assertNull(parseCanonicalUuid("3f2504e0-4f89-11d3-9a0c"))
    }

    @Test
    fun `parseCanonicalUuid returns null for a null value`() {
        assertNull(parseCanonicalUuid(null))
    }

    @Test
    fun `webRedemptionResultToMap flattens a success that describes nothing`() {
        val map = webRedemptionResultToMap(PLYWebRedemptionResult.Success(null, false))

        assertEquals(true, map["isSuccess"])
        assertNull(map["context"])
        assertEquals(false, map["replay"])
        assertNull(map["errorCode"])
        assertNull(map["errorMessage"])
    }

    /**
     * A present context can still carry a null subscription. Both levels stay
     * nullable, so the JS side sees the same two-level shape the native SDKs
     * report.
     */
    @Test
    fun `webRedemptionResultToMap keeps a present context with a null subscription`() {
        val result = PLYWebRedemptionResult.Success(PLYWebRedemptionContext(null), false)

        val map = webRedemptionResultToMap(result)

        assertEquals(true, map["isSuccess"])
        @Suppress("UNCHECKED_CAST")
        val context = map["context"] as Map<String, Any?>
        assertTrue(context.containsKey("subscription"))
        assertNull(context["subscription"])
    }

    @Test
    fun `webRedemptionResultToMap reports a replayed token`() {
        val map = webRedemptionResultToMap(PLYWebRedemptionResult.Success(null, true))

        assertEquals(true, map["isSuccess"])
        assertEquals(true, map["replay"])
    }

    @Test
    fun `webRedemptionResultToMap flattens a failure and keeps the JS shape stable`() {
        val result = PLYWebRedemptionResult.Failure(
            "EXPIRED_REDEMPTION_TOKEN",
            "Redemption link has expired."
        )

        val map = webRedemptionResultToMap(result)

        assertEquals(false, map["isSuccess"])
        assertNull(map["context"])
        // A failure still reports replay, so the JS shape never changes.
        assertEquals(false, map["replay"])
        assertEquals("EXPIRED_REDEMPTION_TOKEN", map["errorCode"])
        assertEquals("Redemption link has expired.", map["errorMessage"])
    }

    /** A transport or parsing failure never reached the server, so it has no code. */
    @Test
    fun `webRedemptionResultToMap accepts a failure with no error code`() {
        val map = webRedemptionResultToMap(PLYWebRedemptionResult.Failure(null, "Network error"))

        assertEquals(false, map["isSuccess"])
        assertNull(map["errorCode"])
        assertEquals("Network error", map["errorMessage"])
    }

    // endregion
}

/**
 * Additional tests for enum ordinal consistency
 */
class EnumOrdinalConsistencyTest {

    @Test
    fun `LogLevel enum should have expected values`() {
        assertEquals(0, LogLevel.DEBUG.ordinal)
        // Other values may vary, just ensure they exist
        assertNotNull(LogLevel.INFO)
        assertNotNull(LogLevel.WARN)
        assertNotNull(LogLevel.ERROR)
    }

    @Test
    fun `PLYProductViewResult enum should have expected values`() {
        // Verify enum exists with expected members
        assertNotNull(PLYProductViewResult.PURCHASED)
        assertNotNull(PLYProductViewResult.CANCELLED)
        assertNotNull(PLYProductViewResult.RESTORED)
    }

    @Test
    fun `StoreType enum should have expected values`() {
        assertNotNull(StoreType.APPLE_APP_STORE)
        assertNotNull(StoreType.GOOGLE_PLAY_STORE)
        assertNotNull(StoreType.HUAWEI_APP_GALLERY)
        assertNotNull(StoreType.AMAZON_APP_STORE)
        assertNotNull(StoreType.NONE)
    }

    @Test
    fun `DistributionType enum should have expected values`() {
        assertNotNull(DistributionType.CONSUMABLE)
        assertNotNull(DistributionType.NON_CONSUMABLE)
        assertNotNull(DistributionType.RENEWING_SUBSCRIPTION)
        assertNotNull(DistributionType.NON_RENEWING_SUBSCRIPTION)
        assertNotNull(DistributionType.UNKNOWN)
    }

    @Test
    fun `PLYPresentationType enum should have expected values`() {
        assertNotNull(PLYPresentationType.NORMAL)
        assertNotNull(PLYPresentationType.FALLBACK)
        assertNotNull(PLYPresentationType.DEACTIVATED)
        assertNotNull(PLYPresentationType.CLIENT)
    }

    @Test
    fun `PLYThemeMode enum should have expected values`() {
        assertNotNull(PLYThemeMode.LIGHT)
        assertNotNull(PLYThemeMode.DARK)
        assertNotNull(PLYThemeMode.SYSTEM)
    }

    @Test
    fun `PLYUserAttributeSource enum should have expected values`() {
        assertNotNull(PLYUserAttributeSource.PURCHASELY)
        assertNotNull(PLYUserAttributeSource.CLIENT)
    }

    @Test
    fun `PLYUserAttributeType enum should have expected values`() {
        assertNotNull(PLYUserAttributeType.STRING)
        assertNotNull(PLYUserAttributeType.BOOLEAN)
        assertNotNull(PLYUserAttributeType.INT)
        assertNotNull(PLYUserAttributeType.FLOAT)
        assertNotNull(PLYUserAttributeType.DATE)
        assertNotNull(PLYUserAttributeType.STRING_ARRAY)
        assertNotNull(PLYUserAttributeType.INT_ARRAY)
        assertNotNull(PLYUserAttributeType.FLOAT_ARRAY)
        assertNotNull(PLYUserAttributeType.BOOLEAN_ARRAY)
    }

    @Test
    fun `Attribute enum should have marketing attribution values`() {
        assertNotNull(Attribute.FIREBASE_APP_INSTANCE_ID)
        assertNotNull(Attribute.AIRSHIP_CHANNEL_ID)
        assertNotNull(Attribute.AIRSHIP_USER_ID)
        assertNotNull(Attribute.BATCH_INSTALLATION_ID)
        assertNotNull(Attribute.ADJUST_ID)
        assertNotNull(Attribute.APPSFLYER_ID)
        assertNotNull(Attribute.MIXPANEL_DISTINCT_ID)
        assertNotNull(Attribute.CLEVER_TAP_ID)
        assertNotNull(Attribute.SENDINBLUE_USER_EMAIL)
        assertNotNull(Attribute.ITERABLE_USER_ID)
        assertNotNull(Attribute.ITERABLE_USER_EMAIL)
        assertNotNull(Attribute.AT_INTERNET_ID_CLIENT)
        assertNotNull(Attribute.AMPLITUDE_USER_ID)
        assertNotNull(Attribute.AMPLITUDE_DEVICE_ID)
        assertNotNull(Attribute.MPARTICLE_USER_ID)
        assertNotNull(Attribute.CUSTOMERIO_USER_ID)
        assertNotNull(Attribute.CUSTOMERIO_USER_EMAIL)
        assertNotNull(Attribute.BRANCH_USER_DEVELOPER_IDENTITY)
        assertNotNull(Attribute.MOENGAGE_UNIQUE_ID)
        assertNotNull(Attribute.BATCH_CUSTOM_USER_ID)
        // [ENM-04 / REC-11]
        assertNotNull(Attribute.ONESIGNAL_EXTERNAL_ID)
        assertNotNull(Attribute.ONESIGNAL_USER_ID)
    }
}
