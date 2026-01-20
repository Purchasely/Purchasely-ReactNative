package com.reactnativepurchasely

import com.facebook.react.bridge.ReactApplicationContext
import io.purchasely.ext.*
import io.purchasely.storage.userData.PLYUserAttributeSource
import io.purchasely.storage.userData.PLYUserAttributeType
import io.purchasely.views.presentation.PLYThemeMode
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.mock
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

    @Test
    fun `getConstants should contain running mode constants`() {
        val constants = purchaselyModule.constants

        assertTrue(constants.containsKey("runningModeTransactionOnly"))
        assertTrue(constants.containsKey("runningModeObserver"))
        assertTrue(constants.containsKey("runningModePaywallObserver"))
        assertTrue(constants.containsKey("runningModeFull"))
    }

    @Test
    fun `running mode constants should be unique`() {
        val constants = purchaselyModule.constants

        val runningModes = setOf(
            constants["runningModeTransactionOnly"],
            constants["runningModeObserver"],
            constants["runningModePaywallObserver"],
            constants["runningModeFull"]
        )

        assertEquals(4, runningModes.size)
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
    }
}
