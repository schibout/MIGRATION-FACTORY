import { configureStore } from '@reduxjs/toolkit';
import extractionReducer from './slices/extractionSlice';
import dataReducer from './slices/dataSlice';
import authReducer from './slices/authSlice';
import configReducer from './slices/configSlice';
import hermesChatReducer from './slices/hermesChatSlice';

export const store = configureStore({
  reducer: {
    extraction: extractionReducer,
    data: dataReducer,
    auth: authReducer,
    config: configReducer,
    hermesChat: hermesChatReducer,
  },
  middleware: (getDefaultMiddleware) => 
    getDefaultMiddleware({
      serializableCheck: false,
    }),
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch; 