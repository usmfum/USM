import {combineReducers} from 'redux';

function display(state = {}, action) {
    switch (action.type) {
        default:
            return state;
    }
}

const rootReducer = new combineReducers({
    display
});

export default rootReducer;