import React from 'react'
import { StyleSheet, useColorScheme, View } from 'react-native'

interface IProps {
    children: React.ReactNode
}

export const Section: React.FC<IProps> = ({ children }) => {
    const isDarkMode = useColorScheme() === 'dark'
    return <View style={styles.sectionContainer}>{children}</View>
}

const styles = StyleSheet.create({
    sectionContainer: {
        marginTop: 12,
        paddingHorizontal: 24,
    },
})
