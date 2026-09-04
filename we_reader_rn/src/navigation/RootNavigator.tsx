import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Text } from 'react-native';
import type { RootStackParamList, TabParamList } from './types';
import DiscoverScreen from '../screens/DiscoverScreen';
import ShelfScreen from '../screens/ShelfScreen';
import ProfileScreen from '../screens/ProfileScreen';
import SearchScreen from '../screens/SearchScreen';
import BookDetailScreen from '../screens/BookDetailScreen';
import ReaderScreen from '../screens/ReaderScreen';

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator<TabParamList>();

const TAB_ICONS: Record<keyof TabParamList, string> = {
  Discover: '🧭',
  Shelf: '📚',
  Profile: '👤',
};
const TAB_LABELS: Record<keyof TabParamList, string> = {
  Discover: '发现',
  Shelf: '书架',
  Profile: '我',
};

function Tabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: () => <Text style={{ fontSize: 18 }}>{TAB_ICONS[route.name as keyof TabParamList]}</Text>,
        tabBarLabel: TAB_LABELS[route.name as keyof TabParamList],
      })}
    >
      <Tab.Screen name="Discover" component={DiscoverScreen} />
      <Tab.Screen name="Shelf" component={ShelfScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
}

export default function RootNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="Tabs" component={Tabs} />
        <Stack.Screen name="Search" component={SearchScreen} options={{ presentation: 'fullScreenModal' }} />
        <Stack.Screen name="BookDetail" component={BookDetailScreen} options={{ headerShown: true, title: '' }} />
        <Stack.Screen name="Reader" component={ReaderScreen} options={{ animation: 'fade' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
